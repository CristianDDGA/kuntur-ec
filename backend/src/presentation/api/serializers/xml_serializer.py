from datetime import date, datetime, time
from decimal import Decimal
from typing import Any
from xml.etree.ElementTree import Element, SubElement, tostring

from .base import ResponseSerializer


def _to_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, Decimal):
        return f"{value:.2f}"
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    return str(value)


def _build(parent: Element, data: Any, item_tag: str = "item") -> None:
    if isinstance(data, dict):
        for key, value in data.items():
            _build(SubElement(parent, str(key)), value)
    elif isinstance(data, list):
        for value in data:
            _build(SubElement(parent, item_tag), value)
    else:
        parent.text = _to_text(data)


class XmlSerializer(ResponseSerializer):
    mimetype = "application/xml"

    def serialize(self, data: Any, root: str = "respuesta") -> str:
        element = Element(root)
        _build(element, data)
        return tostring(element, encoding="unicode", xml_declaration=True)
