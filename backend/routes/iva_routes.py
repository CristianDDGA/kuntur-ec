"""Servicio SOA de IVA: cualquier usuario con sesión consulta; solo el administrador lo cambia."""
from flasgger import swag_from
from flask import Blueprint, current_app

from models import Rol
from services.iva_service import IvaService
from utils.autenticacion import rol_requerido, token_requerido
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

iva_bp = Blueprint("iva", __name__)


def _servicio() -> IvaService:
    return current_app.extensions["iva_service"]


# =============================
# GET - Tarifa vigente e historial
# =============================

@iva_bp.route("", methods=["GET"])
@swag_from(contrato("iva", "consultar"))
@token_requerido
def consultar():
    return respond(_servicio().consultar(), root="iva")


# =============================
# POST - Cambiar el IVA (admin)
# =============================

@iva_bp.route("", methods=["POST"])
@swag_from(contrato("iva", "cambiar"))
@rol_requerido(Rol.ADMIN)
def cambiar():
    tarifa = _servicio().cambiar(cuerpo_json())
    return respond({"mensaje": "Tarifa de IVA registrada correctamente.", "tarifa": tarifa}, status=201, root="iva")
