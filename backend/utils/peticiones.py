"""Lectura de datos de la petición, común a todas las rutas."""
from flask import request

from utils.excepciones import ValidationError


def cuerpo_json() -> dict:
    """Cuerpo JSON de la petición; error 400 si no es un objeto JSON."""
    datos = request.get_json(silent=True)
    if not isinstance(datos, dict):
        raise ValidationError("El cuerpo de la solicitud debe ser un objeto JSON.")
    return datos
