"""Envío de correos (por ahora, el código de verificación del registro).

`EnviadorCorreo` es la interfaz: el servicio no sabe si el correo sale por Gmail o se queda en el log.
- `EnviadorSmtp`: producción y desarrollo con SMTP configurado (Gmail con contraseña de aplicación).
- `EnviadorLocal`: desarrollo/pruebas sin SMTP; escribe el mensaje en el log del servidor en vez de enviarlo.
"""
from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage
from typing import Protocol

from utils.excepciones import ServiceUnavailableError

logger = logging.getLogger(__name__)

_TIMEOUT_SEGUNDOS = 15


class EnviadorCorreo(Protocol):
    def enviar(self, destinatario: str, asunto: str, texto: str, html: str | None = None) -> None: ...


class EnviadorSmtp:
    def __init__(self, host: str, puerto: int, usuario: str, clave: str, remitente: str):
        self._host = host
        self._puerto = puerto
        self._usuario = usuario
        self._clave = clave
        self._remitente = remitente

    def enviar(self, destinatario: str, asunto: str, texto: str, html: str | None = None) -> None:
        mensaje = EmailMessage()
        mensaje["From"] = self._remitente
        mensaje["To"] = destinatario
        mensaje["Subject"] = asunto
        mensaje.set_content(texto)
        if html:
            mensaje.add_alternative(html, subtype="html")
        try:
            with smtplib.SMTP(self._host, self._puerto, timeout=_TIMEOUT_SEGUNDOS) as servidor:
                servidor.starttls(context=ssl.create_default_context())
                servidor.login(self._usuario, self._clave)
                servidor.send_message(mensaje)
        except (smtplib.SMTPException, OSError) as error:
            # El detalle (que podría incluir el usuario SMTP) queda en el log; al cliente solo un mensaje genérico.
            logger.error("No se pudo enviar el correo: %s", type(error).__name__)
            raise ServiceUnavailableError("No se pudo enviar el correo. Intente de nuevo en unos minutos.") from None


class EnviadorLocal:
    """Sin SMTP: deja el mensaje en el log. Solo para desarrollo y pruebas (Settings lo exige fuera de local)."""

    def __init__(self) -> None:
        self.enviados: list[tuple[str, str, str]] = []  # (destinatario, asunto, texto): útil en pruebas

    def enviar(self, destinatario: str, asunto: str, texto: str, html: str | None = None) -> None:
        self.enviados.append((destinatario, asunto, texto))
        logger.warning("[correo local, no se envió] para=%s asunto=%s\n%s", destinatario, asunto, texto)
