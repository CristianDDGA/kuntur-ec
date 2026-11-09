from typing import Any
from xml.etree.ElementTree import Element, SubElement, tostring

from .base import ResponseSerializer
from .primitives import Primitive, to_primitive


def _text(value: Primitive) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _build(parent: Element, data: Primitive, item_tag: str = "item") -> None:
    if isinstance(data, dict):
        for key, value in data.items():
            _build(SubElement(parent, key), value)
    elif isinstance(data, list):
        for value in data:
            _build(SubElement(parent, item_tag), value)
    else:
        parent.text = _text(data)


class XmlSerializer(ResponseSerializer):
    mimetype = "application/xml"

    def serialize(self, data: Any, root: str = "respuesta") -> str:
        element = Element(root)
        _build(element, to_primitive(data))
        return tostring(element, encoding="unicode", xml_declaration=True)
