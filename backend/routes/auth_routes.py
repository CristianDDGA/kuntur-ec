"""Servicio SOA de Autenticación."""
from flasgger import swag_from
from flask import Blueprint, current_app, request

from services.auth_service import AuthService
from utils.autenticacion import sesion_actual, token_requerido, publica
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

auth_bp = Blueprint("auth", __name__)


def _servicio() -> AuthService:
    return current_app.extensions["auth_service"]


# =============================
# POST - Iniciar sesión
# =============================

@auth_bp.route("/login", methods=["POST"])
@swag_from(contrato("auth", "login"))
@publica
def login():
    return respond(_servicio().login(cuerpo_json(), origen=request.remote_addr or ""), root="sesion")


# =============================
# POST - Confirmar el correo con el código enviado
# =============================

@auth_bp.route("/verificar-correo", methods=["POST"])
@swag_from(contrato("auth", "verificar_correo"))
@publica
def verificar_correo():
    resultado = current_app.extensions["verificacion_service"].verificar(cuerpo_json())
    return respond({"mensaje": "Correo verificado. Ya puede iniciar sesión.", **resultado}, root="verificacion")


# =============================
# POST - Pedir otro código
# =============================

@auth_bp.route("/reenviar-codigo", methods=["POST"])
@swag_from(contrato("auth", "reenviar_codigo"))
@publica
def reenviar_codigo():
    return respond(current_app.extensions["verificacion_service"].reenviar(cuerpo_json()), root="reenvio")


# =============================
# POST - Cerrar sesión
# =============================

@auth_bp.route("/logout", methods=["POST"])
@swag_from(contrato("auth", "logout"))
@token_requerido
def logout():
    _servicio().logout(sesion_actual())
    return respond({"mensaje": "Sesión cerrada correctamente."}, root="logout")


# =============================
# GET - Perfil del usuario
# =============================

@auth_bp.route("/perfil", methods=["GET"])
@swag_from(contrato("auth", "perfil"))
@token_requerido
def perfil():
    return respond({"usuario": sesion_actual().usuario.to_dict()}, root="perfil")
