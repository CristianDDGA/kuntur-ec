"""Servicio SOA de Usuarios."""
from flasgger import swag_from
from flask import Blueprint, current_app

from services.usuario_service import UsuarioService
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

usuarios_bp = Blueprint("usuarios", __name__)


def _servicio() -> UsuarioService:
    return current_app.extensions["usuario_service"]


# =============================
# POST - Registrar usuario
# =============================

@usuarios_bp.route("/registro", methods=["POST"])
@swag_from(contrato("usuarios", "registrar"))
def registrar():
    usuario = _servicio().registrar(cuerpo_json())
    return respond(
        {"mensaje": "Usuario registrado correctamente.", "usuario": usuario.to_dict()},
        status=201,
        root="registro",
    )
