"""Servicio de recuperación de contraseña: código de 6 dígitos enviado al correo de la cuenta.

Es el mismo mecanismo que la verificación del correo (ver `verificacion_service`), con tabla propia:
- El código se guarda cifrado (HMAC-SHA256 con la clave del servidor), nunca en claro.
- Vence a los 10 minutos y admite 5 intentos; después hay que pedir otro. Un código nuevo reemplaza al anterior.
- Se puede pedir otro cada 60 segundos.
- Pedirlo responde siempre igual, exista o no la cuenta (y salga o no el correo), para no revelar qué correos
  están registrados.
- Al restablecer: se guarda la contraseña nueva, se cierran TODAS las sesiones abiertas de la cuenta y, como el
  código prueba que la persona controla el correo, la cuenta queda verificada.
"""
from __future__ import annotations

import hashlib
import hmac
import html
import logging
import re
import secrets
from typing import Any

from database import Database
from services.usuario_service import Cifrador, validar_contrasena
from services.verificacion_service import DIGITOS, ESPERA_REENVIO_SEGUNDOS, MAX_INTENTOS, VIGENCIA_MINUTOS
from utils.correo import EnviadorCorreo
from utils.excepciones import ValidationError
from utils.limites import CONTRASENA as MAX_LARGO_CONTRASENA
from utils.seguridad import CifradorContrasenas
from utils.validaciones import correo as validar_correo
from utils.validaciones import texto_obligatorio

logger = logging.getLogger(__name__)

_INVALIDO = "El código no es correcto o ya venció. Pida uno nuevo."
_RESPUESTA_SOLICITUD = "Si el correo está registrado, le enviamos un código para restablecer su contraseña."
_RESPUESTA_RESTABLECER = "Contraseña actualizada. Inicie sesión con la nueva contraseña."


class RecuperacionService:
    def __init__(self, db: Database, enviador: EnviadorCorreo, clave: str, cifrador: Cifrador | None = None):
        self._db = db
        self._enviador = enviador
        self._clave = clave.encode("utf-8")
        self._cifrador = cifrador or CifradorContrasenas()

    def _huella(self, usuario_id: int, codigo: str) -> str:
        # El prefijo separa este código del de verificación: aunque coincidieran los dígitos, las huellas difieren.
        return hmac.new(self._clave, f"recuperar:{usuario_id}:{codigo}".encode(), hashlib.sha256).hexdigest()

    # ------------------------------------------------------------ solicitar

    def solicitar(self, datos: dict) -> dict[str, Any]:
        """Envía un código al correo si la cuenta existe y pasó el tiempo de espera. Responde siempre igual."""
        correo = validar_correo(datos)
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT u.id, u.nombre, u.correo, "
                "(c.enviado_en IS NULL OR c.enviado_en < now() - make_interval(secs => %s)) AS puede "
                "FROM usuarios u LEFT JOIN codigos_recuperacion c ON c.usuario_id = u.id "
                "WHERE lower(u.correo) = lower(%s)",
                (ESPERA_REENVIO_SEGUNDOS, correo),
            )
            fila = cur.fetchone()
        if fila is not None and fila["puede"]:
            try:
                self._enviar_codigo(fila["id"], fila["nombre"], fila["correo"])
            except Exception:  # noqa: BLE001 - si el correo falla se responde igual: no se revela si la cuenta existe
                logger.exception("Falló el envío del código de recuperación")
        return {"mensaje": _RESPUESTA_SOLICITUD}

    def _enviar_codigo(self, usuario_id: int, nombre: str, correo: str) -> None:
        codigo = f"{secrets.randbelow(10**DIGITOS):0{DIGITOS}d}"
        with self._db.transaccion() as cur:
            cur.execute(
                "INSERT INTO codigos_recuperacion (usuario_id, codigo_hash, expira, intentos, enviado_en) "
                "VALUES (%s, %s, now() + make_interval(mins => %s), 0, now()) "
                "ON CONFLICT (usuario_id) DO UPDATE SET codigo_hash = EXCLUDED.codigo_hash, "
                "expira = EXCLUDED.expira, intentos = 0, enviado_en = now()",
                (usuario_id, self._huella(usuario_id, codigo), VIGENCIA_MINUTOS),
            )
        self._enviador.enviar(
            correo,
            "Restablezca su contraseña de Kuntur EC",
            f"Hola {nombre},\n\nSu código para restablecer la contraseña es: {codigo}\n\n"
            f"Vence en {VIGENCIA_MINUTOS} minutos. Si usted no lo pidió, ignore este mensaje: su contraseña no cambiará.\n",
            f"<p>Hola {html.escape(nombre)},</p><p>Su código para restablecer la contraseña es:</p>"
            f"<p style='font-size:28px;letter-spacing:6px'><b>{codigo}</b></p>"
            f"<p>Vence en {VIGENCIA_MINUTOS} minutos. Si usted no lo pidió, ignore este mensaje: su contraseña no cambiará.</p>",
        )

    # ------------------------------------------------------------ restablecer

    def restablecer(self, datos: dict) -> dict[str, Any]:
        correo = validar_correo(datos)
        codigo = datos.get("codigo")
        if not isinstance(codigo, str) or not re.fullmatch(rf"[0-9]{{{DIGITOS}}}", codigo.strip()):
            raise ValidationError(f"El código tiene {DIGITOS} dígitos.")
        codigo = codigo.strip()
        # La contraseña se valida antes de tocar la base: una contraseña floja no gasta un intento del código.
        contrasena = texto_obligatorio(datos, "password", MAX_LARGO_CONTRASENA, normalizar=False)
        validar_contrasena(contrasena)

        error: str | None = None
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT u.id, c.codigo_hash, c.intentos, c.expira > now() AS vigente "
                "FROM usuarios u LEFT JOIN codigos_recuperacion c ON c.usuario_id = u.id "
                "WHERE lower(u.correo) = lower(%s) FOR UPDATE OF u",
                (correo,),
            )
            fila = cur.fetchone()
            if fila is None or fila["codigo_hash"] is None:
                error = _INVALIDO
            elif not fila["vigente"] or fila["intentos"] >= MAX_INTENTOS:
                error = _INVALIDO
            elif not hmac.compare_digest(fila["codigo_hash"], self._huella(fila["id"], codigo)):
                cur.execute("UPDATE codigos_recuperacion SET intentos = intentos + 1 WHERE usuario_id = %s", (fila["id"],))
                quedan = MAX_INTENTOS - fila["intentos"] - 1
                error = (
                    f"El código no es correcto. Le quedan {quedan} intentos."
                    if quedan > 0
                    else "El código no es correcto y se agotaron los intentos. Pida uno nuevo."
                )
            else:
                cur.execute(
                    "UPDATE usuarios SET password_hash = %s, correo_verificado = TRUE WHERE id = %s",
                    (self._cifrador.cifrar(contrasena), fila["id"]),
                )
                cur.execute("DELETE FROM codigos_recuperacion WHERE usuario_id = %s", (fila["id"],))
                cur.execute("DELETE FROM codigos_verificacion WHERE usuario_id = %s", (fila["id"],))
                # Quien tuviera la contraseña vieja (o una sesión robada) queda fuera.
                cur.execute("UPDATE tokens SET estado = 'revocado' WHERE usuario_id = %s AND estado = 'activo'", (fila["id"],))
        # El error se lanza fuera de la transacción: así el intento fallido queda contado (no se deshace).
        if error:
            raise ValidationError(error)
        return {"mensaje": _RESPUESTA_RESTABLECER}
