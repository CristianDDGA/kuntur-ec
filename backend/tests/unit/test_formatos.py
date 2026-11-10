import json
from datetime import date
from decimal import Decimal

import pytest

from utils.formatos import JsonFormato, XmlFormato, to_primitive

FACTURA = {"numero": "P001-000015", "fecha": date(2026, 6, 21), "total": Decimal("204.7")}


def test_decimal_se_normaliza_a_dos_decimales_sin_perder_precision():
    assert to_primitive(Decimal("204.7")) == "204.70"
    assert to_primitive(Decimal("0.125")) == "0.13"


def test_json_y_xml_representan_igual_los_mismos_datos():
    as_json = json.loads(JsonFormato().render(FACTURA))
    as_xml = XmlFormato().render(FACTURA, root="factura")

    assert as_json == {"numero": "P001-000015", "fecha": "2026-06-21", "total": "204.70"}
    for value in as_json.values():
        assert f">{value}<" in as_xml


def test_xml_serializa_listas_y_booleanos():
    xml = XmlFormato().render({"vuelos": [{"id": 1, "activo": True}]})
    assert "<vuelos><item><id>1</id><activo>true</activo></item></vuelos>" in xml


def test_tipo_no_soportado_falla_explicitamente():
    with pytest.raises(TypeError):
        to_primitive(object())
