import json
from datetime import date, datetime, time
from decimal import Decimal
from typing import Any

from .base import ResponseSerializer


def _default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    raise TypeError(f"Tipo no serializable: {type(value).__name__}")


class JsonSerializer(ResponseSerializer):
    mimetype = "application/json"

    def serialize(self, data: Any, root: str = "respuesta") -> str:
        return json.dumps(data, default=_default, ensure_ascii=False)
