"""Servicio SOA de Autenticación."""
from flasgger import swag_from
from flask import Blueprint, current_app, request

from services.auth_service import AuthService
from utils.autenticacion import sesion_actual, token_requerido
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
def login():
    return respond(_servicio().login(cuerpo_json(), origen=request.remote_addr or ""), root="sesion")


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
