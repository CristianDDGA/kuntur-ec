import pytest

from models import Rol
from services.auth_service import Sesion
from tests.factories import un_usuario
from utils.excepciones import ConflictError, UnauthorizedError


class IvaFalso:
    def __init__(self):
        self.recibido = None

    def consultar(self):
        return {"vigente": {"id": 2, "porcentaje": "15.00", "estado": "vigente"}, "tarifas": []}

    def cambiar(self, datos):
        self.recibido = datos
        if datos.get("porcentaje") == 99:
            raise ConflictError("Ya hay una tarifa que empieza después.")
        return {"id": 3, "porcentaje": "13.00", "estado": "programada"}


class AuthFalso:
    SESIONES = {"tok-admin": un_usuario(id=1, rol=Rol.ADMIN), "tok-cliente": un_usuario(id=2)}

    def validar(self, token):
        if token not in self.SESIONES:
            raise UnauthorizedError("El token no es válido.")
        return Sesion(self.SESIONES[token], token)


@pytest.fixture
def iva(app):
    falso = IvaFalso()
    app.extensions["iva_service"] = falso
    app.extensions["auth_service"] = AuthFalso()
    return falso


def _h(token):
    return {"Authorization": f"Bearer {token}"}


def test_consultar_requiere_sesion(client, iva):
    assert client.get("/api/iva").status_code == 401


def test_cualquier_usuario_con_sesion_consulta(client, iva):
    resp = client.get("/api/iva", headers=_h("tok-cliente"))
    assert resp.status_code == 200 and resp.get_json()["vigente"]["porcentaje"] == "15.00"


def test_consultar_responde_xml(client, iva):
    resp = client.get("/api/iva", headers=_h("tok-cliente") | {"Accept": "application/xml"})
    assert "<porcentaje>15.00</porcentaje>" in resp.get_data(as_text=True)


@pytest.mark.parametrize("token,status", [(None, 401), ("falso", 401), ("tok-cliente", 403)])
def test_cambiar_solo_lo_hace_el_admin(client, iva, token, status):
    resp = client.post("/api/iva", json={"porcentaje": 13, "vigente_desde": "2027-01-01"}, headers=_h(token) if token else {})
    assert resp.status_code == status
    assert iva.recibido is None  # el servicio ni se tocó


def test_admin_cambia_el_iva(client, iva):
    resp = client.post("/api/iva", json={"porcentaje": 13, "vigente_desde": "2027-01-01"}, headers=_h("tok-admin"))
    assert resp.status_code == 201
    assert resp.get_json()["tarifa"]["estado"] == "programada"
    assert iva.recibido == {"porcentaje": 13, "vigente_desde": "2027-01-01"}


def test_conflicto_es_409(client, iva):
    resp = client.post("/api/iva", json={"porcentaje": 99, "vigente_desde": "2027-01-01"}, headers=_h("tok-admin"))
    assert resp.status_code == 409


def test_cuerpo_que_no_es_json_es_415(client, iva):
    resp = client.post("/api/iva", data="porcentaje=13", headers=_h("tok-admin"))
    assert resp.status_code == 415
