"""Servicio de verificación del correo: código de 6 dígitos enviado por correo al registrarse.

Reglas:
- El código se guarda cifrado (HMAC-SHA256 con la clave del servidor), nunca en claro.
- Vence a los 10 minutos y admite 5 intentos; después hay que pedir otro.
- Se puede pedir otro cada 60 segundos. Pedirlo siempre responde igual, exista o no la cuenta,
  para no revelar qué correos están registrados.
- Un código nuevo reemplaza al anterior (solo hay uno vigente por cuenta).
"""
from __future__ import annotations

import hashlib
import hmac
import logging
import re
import secrets
from typing import Any

from database import Database
from models import Usuario
from utils.correo import EnviadorCorreo
from utils.excepciones import AppError, ValidationError
from utils.validaciones import correo as validar_correo

logger = logging.getLogger(__name__)

DIGITOS = 6
VIGENCIA_MINUTOS = 10
MAX_INTENTOS = 5
ESPERA_REENVIO_SEGUNDOS = 60

_INVALIDO = "El código no es correcto o ya venció. Pida uno nuevo."
_RESPUESTA_REENVIO = "Si la cuenta existe y falta verificarla, le enviamos un código nuevo."


class VerificacionService:
    def __init__(self, db: Database, enviador: EnviadorCorreo, clave: str):
        self._db = db
        self._enviador = enviador
        self._clave = clave.encode("utf-8")

    def _huella(self, usuario_id: int, codigo: str) -> str:
        return hmac.new(self._clave, f"{usuario_id}:{codigo}".encode(), hashlib.sha256).hexdigest()

    # ------------------------------------------------------------ enviar

    def enviar_codigo(self, usuario: Usuario) -> None:
        """Genera un código nuevo (reemplaza al anterior) y lo envía. Lanza ServiceUnavailableError si no sale el correo."""
        codigo = f"{secrets.randbelow(10**DIGITOS):0{DIGITOS}d}"
        with self._db.transaccion() as cur:
            cur.execute(
                "INSERT INTO codigos_verificacion (usuario_id, codigo_hash, expira, intentos, enviado_en) "
                "VALUES (%s, %s, now() + make_interval(mins => %s), 0, now()) "
                "ON CONFLICT (usuario_id) DO UPDATE SET codigo_hash = EXCLUDED.codigo_hash, "
                "expira = EXCLUDED.expira, intentos = 0, enviado_en = now()",
                (usuario.id, self._huella(usuario.id, codigo), VIGENCIA_MINUTOS),  # type: ignore[arg-type]
            )
        self._enviador.enviar(
            usuario.correo,
            "Su código de verificación de Kuntur EC",
            f"Hola {usuario.nombre},\n\nSu código de verificación es: {codigo}\n\n"
            f"Vence en {VIGENCIA_MINUTOS} minutos. Si usted no creó una cuenta en Kuntur EC, ignore este mensaje.\n",
            f"<p>Hola {_escapar(usuario.nombre)},</p><p>Su código de verificación es:</p>"
            f"<p style='font-size:28px;letter-spacing:6px'><b>{codigo}</b></p>"
            f"<p>Vence en {VIGENCIA_MINUTOS} minutos. Si usted no creó una cuenta en Kuntur EC, ignore este mensaje.</p>",
        )

    def enviar_tras_registro(self, usuario: Usuario) -> bool:
        """Envía el primer código. Si el correo falla la cuenta ya existe: devuelve False y la persona puede pedir otro."""
        try:
            self.enviar_codigo(usuario)
            return True
        except AppError:
            return False
        except Exception:  # pragma: no cover - red de seguridad: el registro no debe fallar por el correo
            logger.exception("Falló el envío del código de verificación")
            return False

    # ------------------------------------------------------------ verificar

    def verificar(self, datos: dict) -> dict[str, Any]:
        correo = validar_correo(datos)
        codigo = datos.get("codigo")
        if not isinstance(codigo, str) or not re.fullmatch(rf"[0-9]{{{DIGITOS}}}", codigo.strip()):
            raise ValidationError(f"El código tiene {DIGITOS} dígitos.")
        codigo = codigo.strip()

        error: str | None = None
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT u.id, u.correo_verificado, c.codigo_hash, c.intentos, c.expira > now() AS vigente "
                "FROM usuarios u LEFT JOIN codigos_verificacion c ON c.usuario_id = u.id "
                "WHERE lower(u.correo) = lower(%s) FOR UPDATE OF u",
                (correo,),
            )
            fila = cur.fetchone()
            if fila is None or fila["correo_verificado"] or fila["codigo_hash"] is None:
                error = _INVALIDO
            elif not fila["vigente"] or fila["intentos"] >= MAX_INTENTOS:
                error = _INVALIDO
            elif not hmac.compare_digest(fila["codigo_hash"], self._huella(fila["id"], codigo)):
                cur.execute("UPDATE codigos_verificacion SET intentos = intentos + 1 WHERE usuario_id = %s", (fila["id"],))
                quedan = MAX_INTENTOS - fila["intentos"] - 1
                error = (
                    f"El código no es correcto. Le quedan {quedan} intentos."
                    if quedan > 0
                    else "El código no es correcto y se agotaron los intentos. Pida uno nuevo."
                )
            else:
                cur.execute("UPDATE usuarios SET correo_verificado = TRUE WHERE id = %s", (fila["id"],))
                cur.execute("DELETE FROM codigos_verificacion WHERE usuario_id = %s", (fila["id"],))
        # El error se lanza fuera de la transacción: así el intento fallido queda contado (no se deshace).
        if error:
            raise ValidationError(error)
        return {"correo": correo}

    # ------------------------------------------------------------ reenviar

    def reenviar(self, datos: dict) -> dict[str, Any]:
        correo = validar_correo(datos)
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT u.id, u.nombre, u.correo, u.correo_verificado, "
                "(c.enviado_en IS NULL OR c.enviado_en < now() - make_interval(secs => %s)) AS puede "
                "FROM usuarios u LEFT JOIN codigos_verificacion c ON c.usuario_id = u.id "
                "WHERE lower(u.correo) = lower(%s)",
                (ESPERA_REENVIO_SEGUNDOS, correo),
            )
            fila = cur.fetchone()
        if fila is not None and not fila["correo_verificado"] and fila["puede"]:
            self.enviar_codigo(Usuario.from_row(fila | {"password_hash": "-", "rol": "cliente", "fecha_registro": None}))
        return {"mensaje": _RESPUESTA_REENVIO}


def _escapar(texto: str) -> str:
    return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
