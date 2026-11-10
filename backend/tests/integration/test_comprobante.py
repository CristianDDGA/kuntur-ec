from datetime import datetime, timezone
from xml.etree import ElementTree

import pytest

from models import EstadoReserva, Reserva
from services.auth_service import Sesion
from services.reserva_service import ReservaDetalle
from tests.factories import un_usuario, un_vuelo, una_tarifa
from utils.excepciones import NotFoundError, UnauthorizedError
from utils.factura_xml import armar_datos_factura, generar_factura_xml, numero_factura

ANA = un_usuario(id=1, nombre="Ana Torres", correo="ana@correo.com")


def _detalle(**cambios):
    reserva = Reserva.nueva(1, un_vuelo(), 2, una_tarifa())
    reserva = Reserva(**(reserva.__dict__ | {"id": 58, "fecha_reserva": datetime(2026, 11, 10, 15, 0, tzinfo=timezone.utc)} | cambios))
    return ReservaDetalle(reserva, un_vuelo())


class ReservasFalso:
    def obtener(self, sesion, reserva_id):
        if reserva_id != 58:
            raise NotFoundError("La reserva solicitada no existe.")
        return _detalle()


class AuthFalso:
    def validar(self, token):
        if token != "tok":
            raise UnauthorizedError("El token no es válido.")
        return Sesion(ANA, token)


@pytest.fixture(autouse=True)
def servicios(app):
    app.extensions.update(reserva_service=ReservasFalso(), auth_service=AuthFalso())


H = {"Authorization": "Bearer tok"}
URL = "/api/reservas/58/comprobante"


# ---------------------------------------------------------------- 1. JSON de la factura


def test_el_json_de_la_factura_tiene_la_estructura_de_clase():
    datos = armar_datos_factura(_detalle(), ANA)
    assert set(datos) == {"factura", "cliente", "detalles", "totales", "estado"}
    assert datos["factura"] == {"numero": "KEC-00000058", "fecha": "2026-11-10"}
    assert datos["detalles"] == [{
        "nombre": "Pasaje KEC-101 Quito - Guayaquil (2026-06-21 09:45)",
        "cantidad": 2, "precio": "89.00", "subtotal": "178.00",
    }]
    assert datos["totales"] == {"subtotal": "178.00", "porcentaje_iva": "15.00", "iva": "26.70", "total": "204.70"}
    assert datos["estado"] == "Confirmada"


# ---------------------------------------------------------------- 2. XML a partir del JSON


def test_el_xml_se_arma_seccion_por_seccion_desde_el_json():
    xml = generar_factura_xml(armar_datos_factura(_detalle(estado=EstadoReserva.CANCELADA), ANA))
    raiz = ElementTree.fromstring(xml.encode("utf-8"))  # falla si el XML está mal formado
    assert [hijo.tag for hijo in raiz] == ["cabecera", "cliente", "Detalle", "Totales", "Estado"]
    assert raiz.findtext("cabecera/numero") == "KEC-00000058"
    assert raiz.findtext("cliente/correo") == "ana@correo.com"
    producto = raiz.find("Detalle/producto")
    assert [c.tag for c in producto] == ["Nombre", "Cantidad", "PrecioUnitario", "Subtotal"]
    assert {c.tag: c.text for c in raiz.find("Totales")} == {
        "Subtotal": "178.00", "PorcentajeIVA": "15.00", "IVA": "26.70", "Total": "204.70",
    }
    assert raiz.findtext("Estado") == "Cancelada"
    assert "\n  <cabecera>" in xml  # con formato legible (toprettyxml)


# ---------------------------------------------------------------- endpoint


def test_comprobante_responde_la_factura_en_xml(client):
    resp = client.get(URL, headers=H)
    assert resp.status_code == 200
    assert resp.mimetype == "application/xml"
    assert 'filename="factura-58.xml"' in resp.headers["Content-Disposition"]
    raiz = ElementTree.fromstring(resp.get_data())
    assert raiz.tag == "factura" and raiz.findtext("Totales/Total") == "204.70"


def test_comprobante_es_xml_aunque_se_pida_json(client):
    assert client.get(URL, headers=H | {"Accept": "application/json"}).mimetype == "application/xml"


@pytest.mark.parametrize(("url", "cabeceras", "status"), [(URL, {}, 401), ("/api/reservas/7/comprobante", H, 404)])
def test_comprobante_errores(client, url, cabeceras, status):
    assert client.get(url, headers=cabeceras).status_code == status


def test_numero_de_factura():
    assert numero_factura(7) == "KEC-00000007"
