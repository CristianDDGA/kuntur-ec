"""Decoradores para proteger rutas (la autenticación no se repite en cada ruta).

    @vuelos_bp.post("")
    @rol_requerido(Rol.ADMIN)
    def crear_vuelo():
        sesion = sesion_actual()

Cabecera esperada:  Authorization: Bearer <token>
"""
from __future__ import annotations

from collections.abc import Callable
from functools import wraps
from typing import Any, TypeVar

from flask import current_app, g, request

from models import Rol
from utils.excepciones import ForbiddenError, UnauthorizedError

F = TypeVar("F", bound=Callable[..., Any])


def _token_de_la_cabecera() -> str:
    tipo, _, valor = request.headers.get("Authorization", "").partition(" ")
    if tipo.lower() != "bearer" or not valor.strip():
        raise UnauthorizedError("Debe enviar el token en la cabecera 'Authorization: Bearer <token>'.")
    return valor.strip()


def token_requerido(vista: F) -> F:
    @wraps(vista)
    def envoltura(*args: Any, **kwargs: Any) -> Any:
        g.sesion = current_app.extensions["auth_service"].validar(_token_de_la_cabecera())
        return vista(*args, **kwargs)

    return envoltura  # type: ignore[return-value]


def rol_requerido(*roles: Rol) -> Callable[[F], F]:
    def decorador(vista: F) -> F:
        @wraps(vista)
        @token_requerido
        def envoltura(*args: Any, **kwargs: Any) -> Any:
            if g.sesion.usuario.rol not in roles:
                raise ForbiddenError("No tiene permiso para realizar esta acción.")
            return vista(*args, **kwargs)

        return envoltura  # type: ignore[return-value]

    return decorador


def sesion_actual():
    """Sesión del usuario autenticado (solo dentro de una ruta protegida)."""
    return g.sesion
