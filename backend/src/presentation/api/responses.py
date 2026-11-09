"""Negociación de contenido: responde en JSON (por defecto) o XML.

El cliente elige el formato con la cabecera `Accept`. Los serializadores se
inyectan desde `create_app`: agregar un formato nuevo no modifica este módulo
(principio Abierto/Cerrado).
"""
from __future__ import annotations

from collections.abc import Iterable
from typing import Any

from flask import Flask, Response, current_app, request

from .serializers.base import ResponseSerializer

_EXTENSION_KEY = "content_negotiator"


class ContentNegotiator:
    def __init__(self, serializers: Iterable[ResponseSerializer], default_mimetype: str):
        self._serializers = {s.mimetype: s for s in serializers}
        if default_mimetype not in self._serializers:
            raise ValueError(f"No hay serializador para el formato por defecto {default_mimetype}")
        self._default = default_mimetype

    def select(self) -> ResponseSerializer:
        best = request.accept_mimetypes.best_match(list(self._serializers), default=self._default)
        return self._serializers[best]

    def init_app(self, app: Flask) -> None:
        app.extensions[_EXTENSION_KEY] = self


def respond(data: Any, status: int = 200, root: str = "respuesta") -> Response:
    serializer = current_app.extensions[_EXTENSION_KEY].select()
    return Response(serializer.serialize(data, root), status=status, mimetype=serializer.mimetype)
