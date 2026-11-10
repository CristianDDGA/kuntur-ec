"""Formatos de respuesta de la API: JSON y XML.

`to_primitive` normaliza los tipos una sola vez, así un mismo dato se
representa igual en cualquier formato (sin duplicar conversiones).
"""
from abc import ABC, abstractmethod
from datetime import date, datetime, time
from decimal import ROUND_HALF_UP, Decimal
from enum import Enum
import json
from typing import Any
from xml.etree.ElementTree import Element, SubElement, tostring

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


class Formato(ABC):
    """Representación del cuerpo de una respuesta HTTP."""

    mimetype: str

    @abstractmethod
    def render(self, data: Any, root: str = "respuesta") -> str: ...


class JsonFormato(Formato):
    mimetype = "application/json"

    def render(self, data: Any, root: str = "respuesta") -> str:
        return json.dumps(to_primitive(data), ensure_ascii=False)


class XmlFormato(Formato):
    mimetype = "application/xml"

    def render(self, data: Any, root: str = "respuesta") -> str:
        element = Element(root)
        _build_xml(element, to_primitive(data))
        return tostring(element, encoding="unicode", xml_declaration=True)


def _xml_text(value: Primitive) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _build_xml(parent: Element, data: Primitive, item_tag: str = "item") -> None:
    if isinstance(data, dict):
        for key, value in data.items():
            _build_xml(SubElement(parent, key), value)
    elif isinstance(data, list):
        for value in data:
            _build_xml(SubElement(parent, item_tag), value)
    else:
        parent.text = _xml_text(data)
