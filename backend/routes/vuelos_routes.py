"""Servicio SOA de Vuelos."""
from flasgger import swag_from
from flask import Blueprint, current_app, request

from models import Rol
from services.vuelo_service import VueloService
from utils.autenticacion import rol_requerido
from utils.documentacion import contrato
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

vuelos_bp = Blueprint("vuelos", __name__)


def _servicio() -> VueloService:
    return current_app.extensions["vuelo_service"]


# =============================
# GET - Buscar vuelos
# =============================

@vuelos_bp.route("", methods=["GET"])
@swag_from(contrato("vuelos", "buscar"))
def buscar():
    pagina = _servicio().buscar(
        origen=request.args.get("origen"),
        destino=request.args.get("destino"),
        fecha=request.args.get("fecha"),
        pagina=request.args.get("pagina"),
        por_pagina=request.args.get("por_pagina"),
    )
    return respond(pagina.to_dict(), root="vuelos")


# =============================
# GET - Obtener vuelo por ID
# =============================

@vuelos_bp.route("/<id:vuelo_id>", methods=["GET"])
@swag_from(contrato("vuelos", "detalle"))
def detalle(vuelo_id: int):
    return respond(_servicio().obtener(vuelo_id).to_dict(), root="vuelo")


# =============================
# GET - Mapa de asientos del vuelo
# =============================

@vuelos_bp.route("/<id:vuelo_id>/asientos", methods=["GET"])
@swag_from(contrato("vuelos", "asientos"))
def asientos(vuelo_id: int):
    return respond(_servicio().asientos(vuelo_id), root="asientos")


# =============================
# POST - Crear vuelo (admin)
# =============================

@vuelos_bp.route("", methods=["POST"])
@swag_from(contrato("vuelos", "crear"))
@rol_requerido(Rol.ADMIN)
def crear():
    vuelo = _servicio().crear(cuerpo_json())
    return respond({"mensaje": "Vuelo creado correctamente.", "vuelo": vuelo.to_dict()}, status=201, root="vuelo")
