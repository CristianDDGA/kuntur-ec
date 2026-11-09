"""Negociación de contenido: responde en JSON (por defecto) o XML.

El cliente elige el formato con la cabecera `Accept: application/xml`.
Agregar un formato nuevo = registrar otro ResponseSerializer (principio Abierto/Cerrado).
"""
from typing import Any

from flask import Response, request

from .serializers.base import ResponseSerializer
from .serializers.json_serializer import JsonSerializer
from .serializers.xml_serializer import XmlSerializer

_SERIALIZERS: dict[str, ResponseSerializer] = {
    s.mimetype: s for s in (JsonSerializer(), XmlSerializer())
}
_DEFAULT = "application/json"


def _negotiate() -> ResponseSerializer:
    best = request.accept_mimetypes.best_match(list(_SERIALIZERS), default=_DEFAULT)
    return _SERIALIZERS[best or _DEFAULT]


def respond(data: Any, status: int = 200, root: str = "respuesta") -> Response:
    serializer = _negotiate()
    return Response(serializer.serialize(data, root), status=status, mimetype=serializer.mimetype)
