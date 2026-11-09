"""Traducción de excepciones a respuestas HTTP con formato uniforme y en español:

    {"error": "<codigo>", "mensaje": "<texto>"}

Los códigos de error se toman de las excepciones del dominio (única fuente),
de modo que un 404 de Flask y un NotFoundError del dominio responden igual.
"""
import logging

from flask import Flask
from werkzeug.exceptions import HTTPException

from src.domain.exceptions import (
    ConflictError,
    DomainError,
    ForbiddenError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
)

from .responses import respond

logger = logging.getLogger(__name__)

_STATUS_BY_ERROR: dict[type[DomainError], int] = {
    ValidationError: 400,
    UnauthorizedError: 401,
    ForbiddenError: 403,
    NotFoundError: 404,
    ConflictError: 409,
}
_CODE_BY_STATUS: dict[int, str] = {
    status: cls.code for cls, status in _STATUS_BY_ERROR.items()
} | {405: "metodo_no_permitido", 415: "formato_no_soportado", 500: "error_interno"}

_HTTP_MESSAGES: dict[int, str] = {
    400: "La solicitud no es válida.",
    401: "Se requiere autenticación.",
    403: "No tiene permiso para realizar esta acción.",
    404: "El recurso solicitado no existe.",
    405: "Método HTTP no permitido para este recurso.",
    409: "La solicitud entra en conflicto con el estado actual.",
    415: "Formato de contenido no soportado.",
    500: "Ocurrió un error inesperado.",
}


def _error_body(status: int, mensaje: str | None = None) -> tuple[dict[str, str], int]:
    return {
        "error": _CODE_BY_STATUS.get(status, "error_http"),
        "mensaje": mensaje or _HTTP_MESSAGES.get(status, "Error en la solicitud."),
    }, status


def _status_for(error: DomainError) -> int:
    return next(
        (status for cls, status in _STATUS_BY_ERROR.items() if isinstance(error, cls)), 400
    )


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(DomainError)
    def handle_domain_error(error: DomainError):
        return respond(
            {"error": error.code, "mensaje": error.mensaje}, _status_for(error), root="error"
        )

    @app.errorhandler(HTTPException)
    def handle_http_error(error: HTTPException):
        body, status = _error_body(error.code or 500)
        return respond(body, status, root="error")

    @app.errorhandler(Exception)
    def handle_unexpected(error: Exception):
        logger.exception("Error no controlado")
        body, status = _error_body(500)
        return respond(body, status, root="error")
