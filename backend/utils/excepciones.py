"""Excepciones de negocio de la aplicación.

Los servicios no conocen HTTP: `utils/manejador_errores.py` traduce cada excepción
a un código de estado.
"""


class AppError(Exception):
    """Error base de las reglas de negocio."""

    code = "error_negocio"

    def __init__(self, mensaje: str, **detalles: object):
        super().__init__(mensaje)
        self.mensaje = mensaje
        # Datos extra para el cliente, p. ej. version_actual en un conflicto de versión.
        self.detalles = detalles


class ValidationError(AppError):
    code = "datos_invalidos"


class NotFoundError(AppError):
    code = "no_encontrado"


class ConflictError(AppError):
    code = "conflicto"


class UnauthorizedError(AppError):
    code = "no_autenticado"


class ForbiddenError(AppError):
    code = "sin_permiso"


class TooManyRequestsError(AppError):
    """Demasiados intentos (p. ej. logins fallidos). Se responde 429 con Retry-After."""

    code = "demasiados_intentos"


class ServiceUnavailableError(AppError):
    """Un recurso necesario (la base de datos) no responde. Se responde 503 con Retry-After."""

    code = "servicio_no_disponible"
