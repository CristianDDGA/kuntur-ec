"""Negociación de contenido: las rutas responden con `respond()` y el formato
(JSON por defecto o XML) se elige según la cabecera `Accept`.

Los formatos se registran desde `create_app`: agregar uno nuevo no modifica
este módulo (principio Abierto/Cerrado).
"""
from __future__ import annotations

from collections.abc import Iterable
from typing import Any

from flask import Flask, Response, current_app, request

from utils.formatos import Formato

_EXTENSION_KEY = "content_negotiator"


class ContentNegotiator:
    def __init__(self, formatos: Iterable[Formato], default_mimetype: str):
        self._formatos = {f.mimetype: f for f in formatos}
        if default_mimetype not in self._formatos:
            raise ValueError(f"No hay formato registrado para {default_mimetype}")
        self._default = default_mimetype

    def select(self) -> Formato:
        best = request.accept_mimetypes.best_match(list(self._formatos), default=self._default)
        return self._formatos[best]

    def init_app(self, app: Flask) -> None:
        app.extensions[_EXTENSION_KEY] = self


def respond(data: Any, status: int = 200, root: str = "respuesta") -> Response:
    formato = current_app.extensions[_EXTENSION_KEY].select()
    return Response(formato.render(data, root), status=status, mimetype=formato.mimetype)
