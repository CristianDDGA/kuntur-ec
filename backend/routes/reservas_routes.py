"""Servicio SOA de Reservas. Todas las rutas requieren sesión; el usuario sale del token, no del cuerpo."""
from flasgger import swag_from
from flask import Blueprint, Response, current_app, request

from services.reserva_service import ReservaService
from models import Rol
from utils.autenticacion import rol_requerido, sesion_actual
from utils.documentacion import contrato
from utils.factura_xml import armar_datos_factura, generar_factura_xml
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

reservas_bp = Blueprint("reservas", __name__)

# El administrador gestiona (vuelos, IVA) pero no compra: sus peticiones a reservas responden 403.
solo_clientes = rol_requerido(Rol.CLIENTE)


def _servicio() -> ReservaService:
    return current_app.extensions["reserva_service"]


# =============================
# POST - Crear reserva
# =============================

@reservas_bp.route("", methods=["POST"])
@swag_from(contrato("reservas", "crear"))
@solo_clientes
def crear():
    detalle = _servicio().crear(sesion_actual(), cuerpo_json())
    return respond({"mensaje": "Reserva creada correctamente.", "reserva": detalle.to_dict()}, status=201, root="reserva")


# =============================
# GET - Mis reservas
# =============================

@reservas_bp.route("", methods=["GET"])
@swag_from(contrato("reservas", "listar"))
@solo_clientes
def listar():
    pagina = _servicio().listar(sesion_actual(), request.args.get("pagina"), request.args.get("por_pagina"))
    return respond(pagina.to_dict(), root="reservas")


# =============================
# GET - Obtener reserva por ID
# =============================

@reservas_bp.route("/<id:reserva_id>", methods=["GET"])
@swag_from(contrato("reservas", "detalle"))
@solo_clientes
def detalle(reserva_id: int):
    return respond(_servicio().obtener(sesion_actual(), reserva_id).to_dict(), root="reserva")


# ===================================
# PUT - Modificar reserva (con versión)
# ===================================

@reservas_bp.route("/<id:reserva_id>", methods=["PUT"])
@swag_from(contrato("reservas", "modificar"))
@solo_clientes
def modificar(reserva_id: int):
    detalle = _servicio().modificar(sesion_actual(), reserva_id, cuerpo_json())
    return respond({"mensaje": "Reserva modificada correctamente.", "reserva": detalle.to_dict()}, root="reserva")


# ===================================
# GET - Factura (comprobante) en XML
# ===================================

@reservas_bp.route("/<id:reserva_id>/comprobante", methods=["GET"])
@swag_from(contrato("reservas", "comprobante"))
@solo_clientes
def comprobante(reserva_id: int):
    sesion = sesion_actual()
    detalle = _servicio().obtener(sesion, reserva_id)
    datos_factura = armar_datos_factura(detalle, sesion.usuario)  # 1. JSON de la factura
    xml = generar_factura_xml(datos_factura)                      # 2. XML a partir del JSON
    return Response(
        xml,
        mimetype="application/xml",  # siempre XML: es el comprobante que pide el sistema
        headers={"Content-Disposition": f'inline; filename="factura-{reserva_id}.xml"'},
    )


# =============================
# DELETE - Cancelar reserva
# =============================

@reservas_bp.route("/<id:reserva_id>", methods=["DELETE"])
@swag_from(contrato("reservas", "cancelar"))
@solo_clientes
def cancelar(reserva_id: int):
    detalle = _servicio().cancelar(sesion_actual(), reserva_id)
    return respond({"mensaje": "Reserva cancelada correctamente.", "reserva": detalle.to_dict()}, root="reserva")
