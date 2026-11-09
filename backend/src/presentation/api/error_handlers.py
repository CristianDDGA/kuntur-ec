"""Traducción de excepciones a respuestas HTTP con formato uniforme:

    {"error": "<codigo>", "mensaje": "<texto>"}
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


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(DomainError)
    def handle_domain_error(error: DomainError):
        status = next(
            (code for cls, code in _STATUS_BY_ERROR.items() if isinstance(error, cls)), 400
        )
        return respond({"error": error.code, "mensaje": error.mensaje}, status, root="error")

    @app.errorhandler(HTTPException)
    def handle_http_error(error: HTTPException):
        return respond(
            {"error": error.name.lower().replace(" ", "_"), "mensaje": error.description},
            error.code or 500,
            root="error",
        )

    @app.errorhandler(Exception)
    def handle_unexpected(error: Exception):
        logger.exception("Error no controlado")
        return respond(
            {"error": "error_interno", "mensaje": "Ocurrió un error inesperado."}, 500, root="error"
        )
