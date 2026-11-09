"""Excepciones del dominio.

El dominio no conoce HTTP: la capa de presentación traduce cada excepción
a un código de estado (ver presentation/api/error_handlers.py).
"""


class DomainError(Exception):
    """Error base del dominio."""

    code = "error_dominio"

    def __init__(self, mensaje: str):
        super().__init__(mensaje)
        self.mensaje = mensaje


class ValidationError(DomainError):
    code = "datos_invalidos"


class NotFoundError(DomainError):
    code = "no_encontrado"


class ConflictError(DomainError):
    code = "conflicto"


class UnauthorizedError(DomainError):
    code = "no_autenticado"


class ForbiddenError(DomainError):
    code = "sin_permiso"
