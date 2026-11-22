"""Traducción de excepciones a respuestas HTTP con formato uniforme y en español:

    {"error": "<codigo>", "mensaje": "<texto>"}

Los códigos de error se toman de las excepciones de negocio (única fuente),
de modo que un 404 de Flask y un NotFoundError de un servicio responden igual.

Regla de oro: el cliente NUNCA ve detalles internos (SQL, trazas, nombres de tablas).
El detalle completo se registra en el log del servidor; al cliente solo llega un mensaje genérico.
"""
import logging

import psycopg
from flask import Flask
from werkzeug.exceptions import HTTPException

from utils.excepciones import (
    AppError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
    TooManyRequestsError,
    UnauthorizedError,
    ValidationError,
)
from utils.respuestas import respond

logger = logging.getLogger(__name__)

_SEGUNDOS_REINTENTO_BD = 5

_STATUS_BY_ERROR: dict[type[AppError], int] = {
    ValidationError: 400,
    UnauthorizedError: 401,
    ForbiddenError: 403,
    NotFoundError: 404,
    ConflictError: 409,
    TooManyRequestsError: 429,
    ServiceUnavailableError: 503,
}
_CODE_BY_STATUS: dict[int, str] = {
    status: cls.code for cls, status in _STATUS_BY_ERROR.items()
} | {
    405: "metodo_no_permitido",
    413: "cuerpo_demasiado_grande",
    415: "formato_no_soportado",
    500: "error_interno",
}

_HTTP_MESSAGES: dict[int, str] = {
    400: "La solicitud no es válida.",
    401: "Se requiere autenticación.",
    403: "No tiene permiso para realizar esta acción.",
    404: "El recurso solicitado no existe.",
    405: "Método HTTP no permitido para este recurso.",
    409: "La solicitud entra en conflicto con el estado actual.",
    413: "El cuerpo de la solicitud es demasiado grande.",
    415: "Formato de contenido no soportado. Envíe el cuerpo como application/json.",
    429: "Demasiadas solicitudes. Intente más tarde.",
    500: "Ocurrió un error inesperado.",
    503: "El servicio no está disponible temporalmente. Intente nuevamente en unos segundos.",
}


def _error_body(status: int, mensaje: str | None = None) -> tuple[dict[str, str], int]:
    return {
        "error": _CODE_BY_STATUS.get(status, "error_http"),
        "mensaje": mensaje or _HTTP_MESSAGES.get(status, "Error en la solicitud."),
    }, status


def _status_for(error: AppError) -> int:
    return next(
        (status for cls, status in _STATUS_BY_ERROR.items() if isinstance(error, cls)), 400
    )


def _responder(status: int, mensaje: str | None = None, reintentar_en: int | None = None):
    cuerpo, codigo = _error_body(status, mensaje)
    respuesta = respond(cuerpo, codigo, root="error")
    if reintentar_en is not None:
        respuesta.headers["Retry-After"] = str(reintentar_en)
    return respuesta


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(AppError)
    def handle_domain_error(error: AppError):
        status = _status_for(error)
        respuesta = respond(
            {"error": error.code, "mensaje": error.mensaje, **error.detalles}, status, root="error"
        )
        espera = error.detalles.get("reintentar_en_segundos")
        if espera is not None:
            respuesta.headers["Retry-After"] = str(espera)
        return respuesta

    @app.errorhandler(HTTPException)
    def handle_http_error(error: HTTPException):
        return _responder(error.code or 500)

    # Red de seguridad: errores de PostgreSQL que ningún servicio previó. Se traducen a un
    # código HTTP apropiado y se registran; el mensaje técnico nunca llega al cliente.
    @app.errorhandler(psycopg.DataError)
    def handle_dato_invalido(error: psycopg.DataError):
        logger.warning("La base rechazó un dato: %s", type(error).__name__)
        return _responder(400, "Los datos enviados no son válidos.")

    @app.errorhandler(psycopg.IntegrityError)
    def handle_integridad(error: psycopg.IntegrityError):
        logger.warning("Violación de integridad no prevista: %s", type(error).__name__)
        return _responder(409, "La operación entra en conflicto con los datos existentes.")

    def handle_bd_no_disponible(error: Exception):
        logger.error("Base de datos no disponible: %s", type(error).__name__)
        return _responder(503, reintentar_en=_SEGUNDOS_REINTENTO_BD)

    for clase in (psycopg.OperationalError, psycopg.InterfaceError):
        app.register_error_handler(clase, handle_bd_no_disponible)

    @app.errorhandler(Exception)
    def handle_unexpected(error: Exception):
        logger.exception("Error no controlado")
        return _responder(500)
