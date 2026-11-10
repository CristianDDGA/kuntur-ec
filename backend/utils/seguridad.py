"""Seguridad: cifrado de contraseñas (bcrypt) y tokens de sesión (JWT).

Se usa bcrypt y no SHA256 para las contraseñas: bcrypt es lento a propósito y
agrega una sal aleatoria a cada contraseña, así dos usuarios con la misma clave
tienen hashes distintos y un ataque de fuerza bruta es mucho más costoso.
"""
from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from utils.excepciones import UnauthorizedError

# bcrypt solo considera los primeros 72 bytes; más largo se rechaza en la validación.
LIMITE_BYTES_BCRYPT = 72

# ---------------------------------------------------------------- contraseñas


class CifradorContrasenas:
    def __init__(self, costo: int = 12):
        # costo 12 ≈ 0,25 s por hash: aceptable al registrarse, caro para un atacante.
        # En las pruebas se usa 4 para que sean rápidas.
        self._costo = costo

    def cifrar(self, contrasena: str) -> str:
        return bcrypt.hashpw(contrasena.encode("utf-8"), bcrypt.gensalt(self._costo)).decode("ascii")

    def verificar(self, contrasena: str, hash_guardado: str) -> bool:
        try:
            return bcrypt.checkpw(contrasena.encode("utf-8"), hash_guardado.encode("ascii"))
        except ValueError:  # hash con formato inválido
            return False


# ---------------------------------------------------------------- JWT

_ALGORITMO = "HS256"


@dataclass(frozen=True)
class TokenEmitido:
    valor: str
    expiracion: datetime


@dataclass(frozen=True)
class DatosToken:
    """Lo que se lee de un JWT válido."""

    usuario_id: int
    rol: str
    expiracion: datetime


class EmisorTokens:
    """Firma y verifica los JWT con la clave de JWT_SECRET_KEY (.env)."""

    def __init__(self, clave: str, minutos_validez: int):
        self._clave = clave
        self._validez = timedelta(minutes=minutos_validez)

    def emitir(self, usuario_id: int, rol: str, ahora: datetime | None = None) -> TokenEmitido:
        ahora = ahora or datetime.now(timezone.utc)
        expiracion = ahora + self._validez
        valor = jwt.encode(
            {
                "sub": str(usuario_id),
                "rol": rol,
                "iat": ahora,
                "exp": expiracion,
                "jti": secrets.token_hex(16),  # id único: dos logins nunca dan el mismo token
            },
            self._clave,
            algorithm=_ALGORITMO,
        )
        return TokenEmitido(valor=valor, expiracion=expiracion)

    def leer(self, valor: str) -> DatosToken:
        try:
            datos = jwt.decode(
                valor, self._clave, algorithms=[_ALGORITMO], options={"require": ["sub", "exp", "jti"]}
            )
        except jwt.ExpiredSignatureError:
            raise UnauthorizedError("La sesión expiró. Inicie sesión nuevamente.") from None
        except jwt.InvalidTokenError:
            raise UnauthorizedError("El token no es válido.") from None
        return DatosToken(
            usuario_id=int(datos["sub"]),
            rol=datos.get("rol", ""),
            expiracion=datetime.fromtimestamp(datos["exp"], tz=timezone.utc),
        )


def huella_token(valor: str) -> str:
    """SHA-256 del JWT. En la tabla `tokens` se guarda la huella, no el token:
    si alguien lee la BD no puede usar las sesiones activas."""
    return hashlib.sha256(valor.encode("utf-8")).hexdigest()
