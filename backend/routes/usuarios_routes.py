"""Servicio SOA de Usuarios."""
from flasgger import swag_from
from flask import Blueprint, current_app

from models import Rol

from services.usuario_service import UsuarioService
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.autenticacion import publica, rol_requerido, sesion_actual
from utils.respuestas import respond

usuarios_bp = Blueprint("usuarios", __name__)


def _servicio() -> UsuarioService:
    return current_app.extensions["usuario_service"]


# =============================
# POST - Registrar usuario
# =============================

@usuarios_bp.route("/registro", methods=["POST"])
@swag_from(contrato("usuarios", "registrar"))
@publica
def registrar():
    usuario = _servicio().registrar(cuerpo_json())
    # La cuenta nace sin verificar: se envía el código al correo. Si el correo falla, la cuenta ya existe y la
    # persona puede pedir otro código desde la pantalla de verificación.
    codigo_enviado = current_app.extensions["verificacion_service"].enviar_tras_registro(usuario)
    return respond(
        {
            "mensaje": "Usuario registrado correctamente. Revise su correo para confirmar la cuenta.",
            "usuario": usuario.to_dict(),
            "verificacion_pendiente": True,
            "codigo_enviado": codigo_enviado,
        },
        status=201,
        root="registro",
    )


# =============================
# PUT - Completar la cédula (cuentas que no la tienen, p. ej. creadas con Google)
# =============================

@usuarios_bp.route("/cedula", methods=["PUT"])
@swag_from(contrato("usuarios", "cedula"))
@rol_requerido(Rol.CLIENTE)
def completar_cedula():
    usuario = _servicio().completar_cedula(sesion_actual().usuario_id, cuerpo_json())
    return respond({"mensaje": "Cédula guardada correctamente.", "usuario": usuario.to_dict()}, root="usuario")
