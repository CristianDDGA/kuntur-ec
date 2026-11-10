"""Rutas de estado del servicio."""
from datetime import datetime, timezone

from flask import Blueprint, current_app

from utils.respuestas import respond

health_bp = Blueprint("health", __name__)


def _estado_base_datos() -> str:
    db = current_app.extensions.get("db")
    if db is None:
        return "sin_configurar"
    return "conectada" if db.disponible() else "no_disponible"


@health_bp.get("/health")
def health():
    """Estado del servicio y de la base de datos
    ---
    tags: [Sistema]
    responses:
      200:
        description: El servicio está disponible (base_datos = conectada | no_disponible | sin_configurar).
    """
    return respond(
        {
            "estado": "ok",
            "servicio": "kuntur-ec-api",
            "base_datos": _estado_base_datos(),
            "hora": datetime.now(timezone.utc),
        },
        root="salud",
    )
