"""Servicio SOA de Vuelos."""
from flask import Blueprint, current_app, request

from models import Rol
from services.vuelo_service import VueloService
from utils.autenticacion import rol_requerido
from utils.peticiones import cuerpo_json
from utils.respuestas import respond

vuelos_bp = Blueprint("vuelos", __name__)


def _servicio() -> VueloService:
    return current_app.extensions["vuelo_service"]


@vuelos_bp.get("")
def buscar():
    """Buscar vuelos (desde hoy en adelante)
    ---
    tags: [Vuelos]
    produces: [application/json, application/xml]
    parameters:
      - {in: query, name: origen, type: string, required: false, example: Quito}
      - {in: query, name: destino, type: string, required: false, example: Guayaquil}
      - {in: query, name: fecha, type: string, format: date, required: false, example: "2026-12-01", description: "AAAA-MM-DD"}
    responses:
      200:
        description: Lista de vuelos ordenada por fecha y hora (puede estar vacía).
        schema:
          type: object
          properties:
            total: {type: integer, example: 1}
            vuelos:
              type: array
              items: {$ref: "#/definitions/Vuelo"}
      400:
        description: La fecha no tiene el formato AAAA-MM-DD.
    """
    vuelos = _servicio().buscar(
        origen=request.args.get("origen"),
        destino=request.args.get("destino"),
        fecha=request.args.get("fecha"),
    )
    return respond({"total": len(vuelos), "vuelos": [v.to_dict() for v in vuelos]}, root="vuelos")


@vuelos_bp.get("/<int:vuelo_id>")
def detalle(vuelo_id: int):
    """Detalle de un vuelo
    ---
    tags: [Vuelos]
    produces: [application/json, application/xml]
    parameters:
      - {in: path, name: vuelo_id, type: integer, required: true, example: 1}
    responses:
      200:
        description: Datos del vuelo.
        schema: {$ref: "#/definitions/Vuelo"}
      404:
        description: El vuelo no existe.
    """
    return respond(_servicio().obtener(vuelo_id).to_dict(), root="vuelo")


@vuelos_bp.post("")
@rol_requerido(Rol.ADMIN)
def crear():
    """Crear un vuelo (solo administrador)
    ---
    tags: [Vuelos]
    security: [{Bearer: []}]
    consumes: [application/json]
    produces: [application/json, application/xml]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, capacidad]
          properties:
            codigo: {type: string, example: KT801}
            origen: {type: string, example: Quito}
            destino: {type: string, example: Esmeraldas}
            fecha: {type: string, format: date, example: "2026-12-28"}
            hora_salida: {type: string, example: "08:00", description: "HH:MM"}
            hora_llegada: {type: string, example: "08:45", description: "HH:MM"}
            precio: {type: number, example: 75.50}
            capacidad: {type: integer, example: 80}
    responses:
      201:
        description: Vuelo creado con todos sus asientos disponibles.
        schema:
          type: object
          properties:
            mensaje: {type: string, example: "Vuelo creado correctamente."}
            vuelo: {$ref: "#/definitions/Vuelo"}
      400:
        description: Datos inválidos (campo faltante, formato, fecha pasada, origen igual a destino...).
      401:
        description: Sin token o token inválido.
      403:
        description: El usuario no es administrador.
      409:
        description: Ya existe un vuelo con ese código.
    """
    vuelo = _servicio().crear(cuerpo_json())
    return respond({"mensaje": "Vuelo creado correctamente.", "vuelo": vuelo.to_dict()}, status=201, root="vuelo")
