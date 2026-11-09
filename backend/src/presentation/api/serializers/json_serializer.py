import json
from typing import Any

from .base import ResponseSerializer
from .primitives import to_primitive


class JsonSerializer(ResponseSerializer):
    mimetype = "application/json"

    def serialize(self, data: Any, root: str = "respuesta") -> str:
        return json.dumps(to_primitive(data), ensure_ascii=False)
