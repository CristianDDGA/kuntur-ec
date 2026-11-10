"""Servicio SOA de Usuarios."""
from flask import Blueprint, current_app

from services.usuario_service import UsuarioService
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

usuarios_bp = Blueprint("usuarios", __name__)


def _servicio() -> UsuarioService:
    return current_app.extensions["usuario_service"]


@usuarios_bp.post("/registro")
def registrar():
    """Registrar un usuario (rol cliente)
    ---
    tags: [Usuarios]
    consumes: [application/json]
    produces: [application/json, application/xml]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [nombre, correo, password]
          properties:
            nombre: {type: string, example: "Ana Torres"}
            correo: {type: string, example: "ana@correo.com"}
            password: {type: string, example: "Clave2026", description: "Mínimo 8 caracteres, letras y números"}
    responses:
      201:
        description: Usuario creado (la contraseña nunca se devuelve).
        schema:
          type: object
          properties:
            mensaje: {type: string, example: "Usuario registrado correctamente."}
            usuario:
              type: object
              properties:
                id: {type: integer, example: 2}
                nombre: {type: string}
                correo: {type: string}
                rol: {type: string, example: cliente}
                fecha_registro: {type: string, format: date-time}
      400:
        description: Datos inválidos (campo faltante, correo o contraseña no válidos).
      409:
        description: Ya existe una cuenta con ese correo.
    """
    usuario = _servicio().registrar(cuerpo_json())
    return respond(
        {"mensaje": "Usuario registrado correctamente.", "usuario": usuario.to_dict()},
        status=201,
        root="registro",
    )
