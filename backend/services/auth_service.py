"""Servicio de Autenticación: login, logout y validación de sesiones (JWT + tabla tokens)."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from database import Database
from models import EstadoToken, Rol, Usuario
from services.usuario_service import UsuarioService
from utils.excepciones import CorreoNoVerificadoError, ServiceUnavailableError, UnauthorizedError, ValidationError
from utils.google import VerificadorGoogle
from utils.limitador import LimitadorIntentos
from utils.limites import CONTRASENA as MAX_LARGO_CONTRASENA_LOGIN
from utils.seguridad import CifradorContrasenas, EmisorTokens, huella_token
from utils.validaciones import MAX_LARGO_CORREO, revisar_texto

_CREDENCIALES_INVALIDAS = "Correo o contraseña incorrectos."
_SESION_CERRADA = "La sesión fue cerrada. Inicie sesión nuevamente."

# Hash de una contraseña que nadie usa. Si el correo no existe se verifica contra
# este hash igual: la respuesta tarda lo mismo y no revela qué correos están registrados.
_HASH_SEÑUELO = "$2b$12$trC4IZ6TYkadPx9vVBhv2.PIp3rynA.YxCwdDpqm9tb4t9oLh2gx."


@dataclass(frozen=True)
class Sesion:
    """Usuario autenticado en la petición actual."""

    usuario: Usuario
    token: str

    @property
    def usuario_id(self) -> int:
        return self.usuario.id  # type: ignore[return-value]

    @property
    def es_admin(self) -> bool:
        return self.usuario.rol is Rol.ADMIN


class AuthService:
    def __init__(
        self,
        db: Database,
        usuarios: UsuarioService,
        emisor: EmisorTokens,
        cifrador: CifradorContrasenas | None = None,
        limitador: LimitadorIntentos | None = None,
        verificador_google: VerificadorGoogle | None = None,
    ):
        self._db = db
        self._usuarios = usuarios
        self._emisor = emisor
        self._cifrador = cifrador or CifradorContrasenas()
        self._limitador = limitador or LimitadorIntentos()
        self._google = verificador_google  # None = el inicio con Google no está configurado

    def login(self, datos: dict, origen: str = "") -> dict[str, Any]:
        """`origen` (la IP) junto con el correo identifica los intentos fallidos para el límite."""
        correo, contrasena = datos.get("correo"), datos.get("password")
        if not isinstance(correo, str) or not isinstance(contrasena, str) or not correo.strip() or not contrasena:
            raise ValidationError("El correo y la contraseña son obligatorios.")
        if len(correo) > MAX_LARGO_CORREO or len(contrasena) > MAX_LARGO_CONTRASENA_LOGIN:
            raise ValidationError("El correo o la contraseña superan el largo permitido.")
        revisar_texto(correo, "correo")
        revisar_texto(contrasena, "password")

        clave = f"{origen}|{correo.strip().lower()}"
        self._limitador.verificar(clave)  # 429 antes de gastar tiempo en bcrypt

        usuario = self._usuarios.buscar_por_correo(correo)
        hash_guardado = usuario.password_hash if usuario else _HASH_SEÑUELO
        if not self._cifrador.verificar(contrasena, hash_guardado) or usuario is None:
            self._limitador.registrar_fallo(clave)
            raise UnauthorizedError(_CREDENCIALES_INVALIDAS)
        self._limitador.limpiar(clave)
        if not usuario.correo_verificado:  # la contraseña es correcta, pero falta confirmar el correo
            raise CorreoNoVerificadoError(
                "Falta verificar su correo. Ingrese el código que le enviamos.", correo=usuario.correo
            )

        return self._emitir_sesion(usuario)

    def _emitir_sesion(self, usuario: Usuario) -> dict[str, Any]:
        """Token de sesión (JWT firmado) y su huella en la tabla `tokens`, para poder revocarlo en el logout."""
        emitido = self._emisor.emitir(usuario.id, usuario.rol.value)  # type: ignore[arg-type]
        with self._db.transaccion() as cur:
            cur.execute(
                "INSERT INTO tokens (usuario_id, token, expiracion, estado) VALUES (%s, %s, %s, %s)",
                (usuario.id, huella_token(emitido.valor), emitido.expiracion, EstadoToken.ACTIVO.value),
            )
        return {
            "token": emitido.valor,
            "tipo": "Bearer",
            "expira": emitido.expiracion,
            "usuario": usuario.to_dict(),
        }

    def login_google(self, datos: dict) -> dict[str, Any]:
        """Inicia sesión con un `id_token` de Google. Si no hay cuenta con ese correo se crea (verificada); si ya
        existía con correo y contraseña, se vincula. El servidor decide quién es la persona SOLO con lo que
        Google firmó: nunca con un correo o nombre enviado por el cliente."""
        token = datos.get("id_token")
        if not isinstance(token, str) or not token.strip():
            raise ValidationError("Falta el token de Google (id_token).")
        if len(token) > 4096:
            raise ValidationError("El token de Google supera el largo permitido.")
        revisar_texto(token, "id_token")
        if self._google is None:
            raise ServiceUnavailableError("El inicio de sesión con Google no está disponible en este momento.")

        identidad = self._google.verificar(token.strip())
        usuario = self._usuarios.buscar_por_google_sub(identidad.sub)
        nuevo = False
        if usuario is None:
            existente = self._usuarios.buscar_por_correo(identidad.correo)
            if existente is not None:
                usuario = self._usuarios.vincular_google(existente.id, identidad.sub)  # type: ignore[arg-type]
            else:
                usuario = self._usuarios.crear_desde_google(identidad)
                nuevo = True
        return self._emitir_sesion(usuario) | {"nuevo": nuevo}

    def validar(self, token: str) -> Sesion:
        """Comprueba firma, expiración y que el token no esté revocado en la BD."""
        datos = self._emisor.leer(token)
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT u.id, u.nombre, u.correo, u.password_hash, u.rol, u.fecha_registro, u.cedula, u.correo_verificado "
                "FROM tokens t JOIN usuarios u ON u.id = t.usuario_id "
                "WHERE t.token = %s AND t.usuario_id = %s AND t.estado = %s AND t.expiracion > now()",
                (huella_token(token), datos.usuario_id, EstadoToken.ACTIVO.value),
            )
            fila = cur.fetchone()
        if fila is None:
            raise UnauthorizedError(_SESION_CERRADA)
        return Sesion(usuario=Usuario.from_row(fila), token=token)

    def logout(self, sesion: Sesion) -> None:
        """Revoca el token. Es atómico: si llegan dos logout a la vez, solo uno lo revoca."""
        with self._db.transaccion() as cur:
            cur.execute(
                "UPDATE tokens SET estado = %s WHERE token = %s AND estado = %s",
                (EstadoToken.REVOCADO.value, huella_token(sesion.token), EstadoToken.ACTIVO.value),
            )
            if cur.rowcount == 0:
                raise UnauthorizedError(_SESION_CERRADA)
