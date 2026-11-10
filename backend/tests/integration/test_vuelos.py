import pytest

from models import Rol
from services.auth_service import Sesion
from tests.factories import un_usuario, un_vuelo
from utils.excepciones import ConflictError, NotFoundError, UnauthorizedError

NUEVO = {
    "codigo": "KT801", "origen": "Quito", "destino": "Esmeraldas", "fecha": "2026-12-28",
    "hora_salida": "08:00", "hora_llegada": "08:45", "precio": 75.5, "capacidad": 80,
}


class VuelosFalso:
    def __init__(self):
        self.filtros = None

    def buscar(self, **filtros):
        self.filtros = filtros
        return [un_vuelo(), un_vuelo(id=11, codigo="KEC-102")]

    def obtener(self, vuelo_id):
        if vuelo_id != 10:
            raise NotFoundError("El vuelo solicitado no existe.")
        return un_vuelo()

    def crear(self, datos):
        if datos["codigo"] == "REPETIDO":
            raise ConflictError("Ya existe un vuelo con el código REPETIDO.")
        return un_vuelo(id=50, codigo=datos["codigo"])


class AuthFalso:
    SESIONES = {"tok-admin": un_usuario(id=1, rol=Rol.ADMIN), "tok-cliente": un_usuario(id=2)}

    def validar(self, token):
        if token not in self.SESIONES:
            raise UnauthorizedError("El token no es válido.")
        return Sesion(self.SESIONES[token], token)


@pytest.fixture
def vuelos(app):
    falso = VuelosFalso()
    app.extensions.update(vuelo_service=falso, auth_service=AuthFalso())
    return falso


def _bearer(token):
    return {"Authorization": f"Bearer {token}"}


def test_buscar_pasa_los_filtros_y_devuelve_total(client, vuelos):
    resp = client.get("/api/vuelos?origen=Quito&destino=Guayaquil&fecha=2026-12-01")
    assert resp.status_code == 200
    assert vuelos.filtros == {"origen": "Quito", "destino": "Guayaquil", "fecha": "2026-12-01"}
    cuerpo = resp.get_json()
    assert cuerpo["total"] == 2
    assert cuerpo["vuelos"][0]["precio"] == "89.00"  # montos como texto con 2 decimales


def test_buscar_es_publico_y_responde_xml(client, vuelos):
    resp = client.get("/api/vuelos", headers={"Accept": "application/xml"})
    assert resp.status_code == 200
    assert "<codigo>KEC-101</codigo>" in resp.get_data(as_text=True)


def test_detalle(client, vuelos):
    assert client.get("/api/vuelos/10").get_json()["codigo"] == "KEC-101"
    resp = client.get("/api/vuelos/999")
    assert resp.status_code == 404 and resp.get_json()["error"] == "no_encontrado"


def test_crear_como_admin_es_201(client, vuelos):
    resp = client.post("/api/vuelos", json=NUEVO, headers=_bearer("tok-admin"))
    assert resp.status_code == 201
    assert resp.get_json()["vuelo"]["codigo"] == "KT801"


@pytest.mark.parametrize(
    ("cabeceras", "status", "codigo"),
    [({}, 401, "no_autenticado"), (_bearer("tok-cliente"), 403, "sin_permiso")],
    ids=["sin-token", "cliente"],
)
def test_crear_sin_ser_admin_es_rechazado(client, vuelos, cabeceras, status, codigo):
    resp = client.post("/api/vuelos", json=NUEVO, headers=cabeceras)
    assert resp.status_code == status and resp.get_json()["error"] == codigo


def test_crear_codigo_repetido_es_409(client, vuelos):
    resp = client.post("/api/vuelos", json=NUEVO | {"codigo": "REPETIDO"}, headers=_bearer("tok-admin"))
    assert resp.status_code == 409
