"""Rutas de estado del servicio."""
from datetime import datetime, timezone

from flasgger import swag_from
from flask import Blueprint, current_app

from utils.documentacion import contrato
from utils.respuestas import respond

health_bp = Blueprint("health", __name__)


def _estado_base_datos() -> str:
    db = current_app.extensions.get("db")
    if db is None:
        return "sin_configurar"
    return "conectada" if db.disponible() else "no_disponible"


# =============================
# GET - Estado del servicio
# =============================

@health_bp.route("/health", methods=["GET"])
@swag_from(contrato("sistema", "health"))
def health():
    return respond(
        {
            "estado": "ok",
            "servicio": "kuntur-ec-api",
            "base_datos": _estado_base_datos(),
            "hora": datetime.now(timezone.utc),
        },
        root="salud",
    )
