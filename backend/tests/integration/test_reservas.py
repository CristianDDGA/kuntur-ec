import pytest

from models import Reserva, Rol
from services.auth_service import Sesion
from services.reserva_service import PaginaReservas, ReservaDetalle
from tests.factories import un_usuario, un_vuelo, una_tarifa
from utils.excepciones import ConflictError, NotFoundError, UnauthorizedError


def _detalle(**cambios):
    return ReservaDetalle(Reserva.nueva(1, un_vuelo(), 2, una_tarifa()), un_vuelo(**cambios))


class ReservasFalso:
    def __init__(self):
        self.llamadas = []

    def crear(self, sesion, datos):
        self.llamadas.append(("crear", sesion.usuario_id, datos))
        if datos.get("vuelo_id") == 99:
            raise ConflictError("No hay suficientes asientos disponibles en el vuelo.")
        return _detalle()

    def listar(self, sesion, pagina=None, por_pagina=None):
        self.llamadas.append(("listar", pagina, por_pagina))
        return PaginaReservas([_detalle(), _detalle()], total=2, pagina=1, por_pagina=10)

    def obtener(self, sesion, reserva_id):
        if reserva_id != 58:
            raise NotFoundError("La reserva solicitada no existe.")
        return _detalle()

    def modificar(self, sesion, reserva_id, datos):
        self.llamadas.append(("modificar", reserva_id, datos))
        return _detalle()

    def cancelar(self, sesion, reserva_id):
        self.llamadas.append(("cancelar", reserva_id))
        return _detalle()


class AuthFalso:
    def validar(self, token):
        if token != "tok":
            raise UnauthorizedError("El token no es válido.")
        return Sesion(un_usuario(id=1), token)


@pytest.fixture
def reservas(app):
    falso = ReservasFalso()
    app.extensions.update(reserva_service=falso, auth_service=AuthFalso())
    return falso


H = {"Authorization": "Bearer tok"}


@pytest.mark.parametrize(
    ("metodo", "url"),
    [("post", "/api/reservas"), ("get", "/api/reservas"), ("get", "/api/reservas/58"),
     ("put", "/api/reservas/58"), ("delete", "/api/reservas/58")],
)
def test_todas_las_rutas_requieren_token(client, reservas, metodo, url):
    resp = getattr(client, metodo)(url, json={})
    assert resp.status_code == 401


def test_crear_usa_el_usuario_del_token_e_ignora_usuario_id_del_cuerpo(client, reservas):
    resp = client.post("/api/reservas", json={"vuelo_id": 1, "cantidad": 2, "usuario_id": 999}, headers=H)
    assert resp.status_code == 201
    _, usuario_id, _ = reservas.llamadas[0]
    assert usuario_id == 1
    reserva = resp.get_json()["reserva"]
    assert (reserva["subtotal"], reserva["iva_porcentaje"], reserva["iva_valor"], reserva["total"]) == (
        "178.00", "15.00", "26.70", "204.70",
    )


def test_crear_sin_asientos_es_409(client, reservas):
    resp = client.post("/api/reservas", json={"vuelo_id": 99, "cantidad": 2}, headers=H)
    assert resp.status_code == 409 and resp.get_json()["error"] == "conflicto"


def test_listar_detalle_modificar_y_cancelar(client, reservas):
    assert client.get("/api/reservas", headers=H).get_json()["total"] == 2
    assert client.get("/api/reservas/58", headers=H).status_code == 200
    assert client.get("/api/reservas/7", headers=H).status_code == 404
    assert client.put("/api/reservas/58", json={"cantidad": 3, "version": 1}, headers=H).status_code == 200
    resp = client.delete("/api/reservas/58", headers=H)
    assert resp.status_code == 200 and "cancelada" in resp.get_json()["mensaje"]
    assert reservas.llamadas == [
        ("listar", None, None), ("modificar", 58, {"cantidad": 3, "version": 1}), ("cancelar", 58),
    ]


def test_listar_devuelve_los_datos_de_paginacion_y_pasa_lo_pedido(client, reservas):
    cuerpo = client.get("/api/reservas?pagina=3&por_pagina=5", headers=H).get_json()
    assert (cuerpo["pagina"], cuerpo["por_pagina"], cuerpo["total_paginas"]) == (1, 10, 1)
    assert reservas.llamadas == [("listar", "3", "5")]


def test_listar_en_xml(client, reservas):
    resp = client.get("/api/reservas", headers=H | {"Accept": "application/xml"})
    assert "<total>204.70</total>" in resp.get_data(as_text=True)
    assert "<total_paginas>1</total_paginas>" in resp.get_data(as_text=True)


def test_conflicto_de_version_responde_409_con_la_version_actual(client, app, reservas):
    def modificar(sesion, reserva_id, datos):
        raise ConflictError("Ya actualizaron este registro.", version_actual=5)

    reservas.modificar = modificar
    resp = client.put("/api/reservas/58", json={"cantidad": 3, "version": 4}, headers=H)
    assert resp.status_code == 409
    assert resp.get_json() == {
        "error": "conflicto",
        "mensaje": "Ya actualizaron este registro.",
        "version_actual": 5,
    }


# ---------------------------------------------------------------- el administrador no reserva


class AuthConAdmin(AuthFalso):
    def validar(self, token):
        if token == "tok-admin":
            return Sesion(un_usuario(id=9, rol=Rol.ADMIN), token)
        return super().validar(token)


@pytest.fixture
def con_admin(app):
    falso = ReservasFalso()
    app.extensions.update(reserva_service=falso, auth_service=AuthConAdmin())
    return falso


@pytest.mark.parametrize(
    ("metodo", "url", "cuerpo"),
    [("post", "/api/reservas", {"vuelo_id": 1, "cantidad": 1}), ("get", "/api/reservas", None),
     ("get", "/api/reservas/58", None), ("put", "/api/reservas/58", {"cantidad": 1, "version": 1}),
     ("delete", "/api/reservas/58", None), ("get", "/api/reservas/58/comprobante", None)],
)
def test_el_admin_recibe_403_en_todas_las_rutas_de_reservas(client, con_admin, metodo, url, cuerpo):
    resp = getattr(client, metodo)(url, json=cuerpo, headers={"Authorization": "Bearer tok-admin"})
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "sin_permiso"
    assert con_admin.llamadas == []  # el servicio ni se tocó


def test_el_cliente_sigue_reservando(client, con_admin):
    resp = client.post("/api/reservas", json={"vuelo_id": 1, "cantidad": 1}, headers=H)
    assert resp.status_code == 201
