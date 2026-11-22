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

# Blueprints que no son servicios propios y no pueden llevar decoradores (Swagger UI de flasgger).
_BLUEPRINTS_AJENOS = (None, "flasgger")


def _token_de_la_cabecera() -> str:
    tipo, _, valor = request.headers.get("Authorization", "").partition(" ")
    if tipo.lower() != "bearer" or not valor.strip():
        raise UnauthorizedError("Debe enviar el token en la cabecera 'Authorization: Bearer <token>'.")
    return valor.strip()


def publica(vista: F) -> F:
    """Declara que la ruta no necesita sesión. Toda ruta de la API debe ser `publica` o protegida:
    si no declara nada, la API la rechaza (cerrado por defecto)."""
    vista._acceso = "publica"  # type: ignore[attr-defined]
    return vista


def exigir_acceso_declarado() -> None:
    """before_request: una ruta de la API sin @publica ni @token_requerido/@rol_requerido responde 500
    en vez de quedar abierta por olvido."""
    if request.blueprint in _BLUEPRINTS_AJENOS:
        return  # Swagger, 404 y otras rutas que no son de nuestros servicios
    vista = current_app.view_functions.get(request.endpoint)
    if getattr(vista, "_acceso", None) is None:
        raise RuntimeError(f"La ruta {request.endpoint} no declara su acceso (@publica o @token_requerido).")


def token_requerido(vista: F) -> F:
    @wraps(vista)
    def envoltura(*args: Any, **kwargs: Any) -> Any:
        g.sesion = current_app.extensions["auth_service"].validar(_token_de_la_cabecera())
        return vista(*args, **kwargs)

    envoltura._acceso = "protegida"  # type: ignore[attr-defined]
    return envoltura  # type: ignore[return-value]


def rol_requerido(*roles: Rol) -> Callable[[F], F]:
    def decorador(vista: F) -> F:
        @wraps(vista)
        @token_requerido
        def envoltura(*args: Any, **kwargs: Any) -> Any:
            if g.sesion.usuario.rol not in roles:
                raise ForbiddenError("No tiene permiso para realizar esta acción.")
            return vista(*args, **kwargs)

        envoltura._acceso = "protegida"  # type: ignore[attr-defined]
        return envoltura  # type: ignore[return-value]

    return decorador


def sesion_actual():
    """Sesión del usuario autenticado (solo dentro de una ruta protegida)."""
    return g.sesion
