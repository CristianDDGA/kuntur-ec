"""Excepciones de negocio de la aplicación.

Los servicios no conocen HTTP: `utils/manejador_errores.py` traduce cada excepción
a un código de estado.
"""


class AppError(Exception):
    """Error base de las reglas de negocio."""

    code = "error_negocio"

    def __init__(self, mensaje: str):
        super().__init__(mensaje)
        self.mensaje = mensaje


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
