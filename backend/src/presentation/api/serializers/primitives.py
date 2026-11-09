"""Normalización única de tipos de Python a primitivos serializables.

Todos los serializadores (JSON, XML, ...) parten de esta salida, así una
misma respuesta se representa igual en cualquier formato.
"""
from datetime import date, datetime, time
from decimal import ROUND_HALF_UP, Decimal
from enum import Enum
from typing import Any

Primitive = str | int | float | bool | None | dict[str, "Primitive"] | list["Primitive"]

_DOS_DECIMALES = Decimal("0.01")


def to_primitive(value: Any) -> Primitive:
    """Convierte recursivamente `value` en tipos nativos de JSON.

    - Decimal -> str con 2 decimales (evita la pérdida de precisión de float en montos).
    - date/datetime/time -> ISO 8601.
    - Enum -> su valor.
    """
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, Decimal):
        return str(value.quantize(_DOS_DECIMALES, rounding=ROUND_HALF_UP))
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if isinstance(value, Enum):
        return to_primitive(value.value)
    if isinstance(value, dict):
        return {str(k): to_primitive(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [to_primitive(v) for v in value]
    raise TypeError(f"Tipo no serializable: {type(value).__name__}")
