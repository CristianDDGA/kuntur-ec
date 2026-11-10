"""Lectura de datos de la petición, común a todas las rutas."""
from flask import abort, request

from utils.excepciones import ValidationError
from utils.validaciones import revisar_json


def cuerpo_json() -> dict:
    """Cuerpo JSON de la petición ya revisado.

    - 415 si se envía un cuerpo que no declara `Content-Type: application/json`.
    - 413 si supera MAX_CONTENT_LENGTH (lo aplica Flask al leerlo).
    - 400 si no es un objeto JSON, está mal formado, es demasiado profundo o trae
      caracteres de control / números no finitos (NaN, Infinity).
    """
    if not request.is_json:
        if request.get_data():
            abort(415)
        raise ValidationError("El cuerpo de la solicitud debe ser un objeto JSON.")
    try:
        datos = request.get_json(silent=True)
    except RecursionError:
        raise ValidationError("El JSON está demasiado anidado.") from None
    if not isinstance(datos, dict):
        raise ValidationError("El cuerpo de la solicitud debe ser un objeto JSON.")
    revisar_json(datos)
    return datos
