"""Servicio SOA de Autenticación."""
from flask import Blueprint, current_app

from services.auth_service import AuthService
from utils.autenticacion import sesion_actual, token_requerido
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

auth_bp = Blueprint("auth", __name__)


def _servicio() -> AuthService:
    return current_app.extensions["auth_service"]


@auth_bp.post("/login")
def login():
    """Iniciar sesión y obtener un JWT
    ---
    tags: [Autenticación]
    consumes: [application/json]
    produces: [application/json, application/xml]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [correo, password]
          properties:
            correo: {type: string, example: "ana@correo.com"}
            password: {type: string, example: "Clave2026"}
    responses:
      200:
        description: Sesión iniciada. Use el token en la cabecera "Authorization Bearer token".
        schema:
          type: object
          properties:
            token: {type: string}
            tipo: {type: string, example: Bearer}
            expira: {type: string, format: date-time}
            usuario: {type: object}
      400:
        description: Falta el correo o la contraseña.
      401:
        description: Correo o contraseña incorrectos.
    """
    return respond(_servicio().login(cuerpo_json()), root="sesion")


@auth_bp.post("/logout")
@token_requerido
def logout():
    """Cerrar sesión (revoca el token)
    ---
    tags: [Autenticación]
    security: [{Bearer: []}]
    produces: [application/json, application/xml]
    responses:
      200:
        description: Sesión cerrada; el token ya no sirve.
      401:
        description: Sin token, token inválido, expirado o ya revocado.
    """
    _servicio().logout(sesion_actual())
    return respond({"mensaje": "Sesión cerrada correctamente."}, root="logout")


@auth_bp.get("/perfil")
@token_requerido
def perfil():
    """Datos del usuario autenticado
    ---
    tags: [Autenticación]
    security: [{Bearer: []}]
    produces: [application/json, application/xml]
    responses:
      200:
        description: Usuario dueño del token.
      401:
        description: Sin token, token inválido, expirado o revocado.
    """
    return respond({"usuario": sesion_actual().usuario.to_dict()}, root="perfil")
