"""Servicio SOA de Aviones (solo administrador): listar e importar desde un CSV."""
from flasgger import swag_from
from flask import Blueprint, abort, current_app, request

from models import Rol
from services.avion_service import AvionService
from utils.autenticacion import rol_requerido
from utils.documentacion import contrato
from utils.limites import BYTES_CSV
from utils.respuestas import respond

aviones_bp = Blueprint("aviones", __name__)


def _servicio() -> AvionService:
    return current_app.extensions["avion_service"]


def _csv() -> bytes:
    """Cuerpo de la petición: el archivo CSV tal cual (Content-Type text/csv). Máximo BYTES_CSV (413)."""
    if request.mimetype not in ("text/csv", "text/plain", "application/csv"):
        abort(415)
    request.max_content_length = BYTES_CSV  # esta ruta admite archivos más grandes que los JSON
    return request.get_data()


# =============================
# GET - Listar aviones (admin)
# =============================

@aviones_bp.route("", methods=["GET"])
@swag_from(contrato("aviones", "listar"))
@rol_requerido(Rol.ADMIN)
def listar():
    aviones = _servicio().listar()
    return respond({"total": len(aviones), "aviones": [a.to_dict() for a in aviones]}, root="aviones")


# =============================
# POST - Previsualizar el CSV (admin): no guarda nada
# =============================

@aviones_bp.route("/importacion/validar", methods=["POST"])
@swag_from(contrato("aviones", "validar"))
@rol_requerido(Rol.ADMIN)
def validar():
    return respond(_servicio().validar(_csv()), root="validacion")


# =============================
# POST - Importar el CSV (admin): todo o nada
# =============================

@aviones_bp.route("/importacion", methods=["POST"])
@swag_from(contrato("aviones", "importar"))
@rol_requerido(Rol.ADMIN)
def importar():
    resultado = _servicio().importar(_csv())
    return respond({"mensaje": "Aviones importados correctamente.", **resultado}, status=201, root="importacion")
