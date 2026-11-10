"""Convertidor de rutas para identificadores: `<id:vuelo_id>`.

Acepta solo enteros positivos que caben en BIGINT. Un id negativo, con ceros a la
izquierda o gigante no coincide con la ruta y responde 404 sin llegar a la base de datos.
"""
from werkzeug.routing import BaseConverter


class IdConverter(BaseConverter):
    regex = r"[1-9][0-9]{0,17}"

    def to_python(self, value: str) -> int:
        return int(value)

    def to_url(self, value: int) -> str:
        return str(value)
