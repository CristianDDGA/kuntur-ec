"""Verificación de los tokens de «Iniciar sesión con Google».

El cliente (Flutter) obtiene de Google un `id_token` (un JWT firmado por Google). El servidor NUNCA confía en lo que
diga el cliente sobre quién es la persona: valida el token con las claves públicas de Google (firma, vencimiento,
emisor y que haya sido emitido para NUESTRO ID de cliente) y solo entonces usa el correo y el nombre que trae.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

from google.auth import exceptions as errores_google
from google.auth.transport import requests as transporte
from google.oauth2 import id_token

from utils.excepciones import ServiceUnavailableError, UnauthorizedError

logger = logging.getLogger(__name__)

_NO_VALIDO = "No se pudo validar su cuenta de Google. Intente de nuevo."


@dataclass(frozen=True)
class IdentidadGoogle:
    sub: str  # identificador estable de la cuenta de Google (no cambia aunque cambie el correo)
    correo: str
    nombre: str


class VerificadorGoogle(Protocol):
    def verificar(self, token: str) -> IdentidadGoogle: ...


class VerificadorGoogleReal:
    def __init__(self, client_id: str):
        self._client_id = client_id
        self._peticion = transporte.Request()  # reutiliza la conexión; google-auth guarda en caché las claves

    def verificar(self, token: str) -> IdentidadGoogle:
        try:
            datos = id_token.verify_oauth2_token(token, self._peticion, self._client_id)
        except ValueError:  # firma, vencimiento, emisor o destinatario (audience) incorrectos
            raise UnauthorizedError(_NO_VALIDO) from None
        except errores_google.TransportError as error:  # no se pudo consultar a Google
            logger.error("No se pudo consultar a Google: %s", type(error).__name__)
            raise ServiceUnavailableError("No se pudo contactar a Google. Intente de nuevo en unos minutos.") from None

        correo = str(datos.get("email") or "").strip().lower()
        # Sin correo verificado por Google no se puede confiar en que la persona sea dueña de esa dirección.
        if not correo or datos.get("email_verified") is not True or not datos.get("sub"):
            raise UnauthorizedError("Su cuenta de Google no tiene un correo verificado.")
        nombre = " ".join(str(datos.get("name") or "").split()) or correo.split("@")[0]
        return IdentidadGoogle(sub=str(datos["sub"]), correo=correo, nombre=nombre)
