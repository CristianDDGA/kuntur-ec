from datetime import datetime, timezone

from flask import Blueprint

from ..responses import respond

health_bp = Blueprint("health", __name__)


@health_bp.get("/health")
def health():
    """Estado del servicio
    ---
    tags: [Sistema]
    responses:
      200:
        description: El servicio está disponible.
    """
    return respond(
        {"estado": "ok", "servicio": "kuntur-ec-api", "hora": datetime.now(timezone.utc)},
        root="salud",
    )
