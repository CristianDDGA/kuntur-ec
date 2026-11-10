"""Servicio SOA de Reservas. Todas las rutas requieren sesión; el usuario sale del token, no del cuerpo."""
from flasgger import swag_from
from flask import Blueprint, current_app

from services.reserva_service import ReservaService
from utils.autenticacion import sesion_actual, token_requerido
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

reservas_bp = Blueprint("reservas", __name__)


def _servicio() -> ReservaService:
    return current_app.extensions["reserva_service"]


# =============================
# POST - Crear reserva
# =============================

@reservas_bp.route("", methods=["POST"])
@swag_from(contrato("reservas", "crear"))
@token_requerido
def crear():
    detalle = _servicio().crear(sesion_actual(), cuerpo_json())
    return respond({"mensaje": "Reserva creada correctamente.", "reserva": detalle.to_dict()}, status=201, root="reserva")


# =============================
# GET - Mis reservas
# =============================

@reservas_bp.route("", methods=["GET"])
@swag_from(contrato("reservas", "listar"))
@token_requerido
def listar():
    reservas = _servicio().listar(sesion_actual())
    return respond({"total": len(reservas), "reservas": [r.to_dict() for r in reservas]}, root="reservas")


# =============================
# GET - Obtener reserva por ID
# =============================

@reservas_bp.route("/<int:reserva_id>", methods=["GET"])
@swag_from(contrato("reservas", "detalle"))
@token_requerido
def detalle(reserva_id: int):
    return respond(_servicio().obtener(sesion_actual(), reserva_id).to_dict(), root="reserva")


# ===================================
# PUT - Modificar reserva (con versión)
# ===================================

@reservas_bp.route("/<int:reserva_id>", methods=["PUT"])
@swag_from(contrato("reservas", "modificar"))
@token_requerido
def modificar(reserva_id: int):
    detalle = _servicio().modificar(sesion_actual(), reserva_id, cuerpo_json())
    return respond({"mensaje": "Reserva modificada correctamente.", "reserva": detalle.to_dict()}, root="reserva")


# =============================
# DELETE - Cancelar reserva
# =============================

@reservas_bp.route("/<int:reserva_id>", methods=["DELETE"])
@swag_from(contrato("reservas", "cancelar"))
@token_requerido
def cancelar(reserva_id: int):
    detalle = _servicio().cancelar(sesion_actual(), reserva_id)
    return respond({"mensaje": "Reserva cancelada correctamente.", "reserva": detalle.to_dict()}, root="reserva")
