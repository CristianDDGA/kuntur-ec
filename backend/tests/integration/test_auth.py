import pytest
from flask import Blueprint

from models import Rol
from services.auth_service import Sesion
from tests.factories import un_usuario
from utils.autenticacion import rol_requerido
from utils.excepciones import UnauthorizedError
from utils.respuestas import respond

TOKENS = {"tok-cliente": un_usuario(id=1), "tok-admin": un_usuario(id=2, rol=Rol.ADMIN)}


class AuthFalso:
    def __init__(self):
        self.revocados = set()

    def login(self, datos, origen=""):
        if datos.get("password") != "Clave2026":
            raise UnauthorizedError("Correo o contraseña incorrectos.")
        return {"token": "tok-cliente", "tipo": "Bearer", "usuario": TOKENS["tok-cliente"].to_dict()}

    def validar(self, token):
        if token not in TOKENS or token in self.revocados:
            raise UnauthorizedError("La sesión fue cerrada. Inicie sesión nuevamente.")
        return Sesion(TOKENS[token], token)

    def logout(self, sesion):
        self.revocados.add(sesion.token)


@pytest.fixture(autouse=True)
def auth(app):
    app.extensions["auth_service"] = AuthFalso()


def _bearer(token):
    return {"Authorization": f"Bearer {token}"}


def test_login_correcto(client):
    resp = client.post("/api/auth/login", json={"correo": "juan@correo.com", "password": "Clave2026"})
    assert resp.status_code == 200
    assert resp.get_json()["token"] == "tok-cliente"


def test_login_incorrecto_es_401(client):
    resp = client.post("/api/auth/login", json={"correo": "juan@correo.com", "password": "mala"})
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "no_autenticado"


@pytest.mark.parametrize(
    "cabeceras",
    [{}, {"Authorization": "tok-cliente"}, {"Authorization": "Bearer "}, _bearer("falso")],
    ids=["sin-cabecera", "sin-bearer", "bearer-vacio", "token-desconocido"],
)
def test_ruta_protegida_sin_token_valido_es_401(client, cabeceras):
    resp = client.get("/api/auth/perfil", headers=cabeceras)
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "no_autenticado"


def test_perfil_con_token_valido(client):
    resp = client.get("/api/auth/perfil", headers=_bearer("tok-cliente"))
    assert resp.status_code == 200
    assert resp.get_json()["usuario"]["id"] == 1


def test_despues_del_logout_el_token_ya_no_sirve(client):
    assert client.post("/api/auth/logout", headers=_bearer("tok-cliente")).status_code == 200
    assert client.get("/api/auth/perfil", headers=_bearer("tok-cliente")).status_code == 401
    assert client.post("/api/auth/logout", headers=_bearer("tok-cliente")).status_code == 401


def test_rol_requerido_permite_admin_y_rechaza_cliente(app, client):
    bp = Blueprint("solo_admin", __name__)

    @bp.get("/solo-admin")
    @rol_requerido(Rol.ADMIN)
    def solo_admin():
        return respond({"ok": True})

    app.register_blueprint(bp, url_prefix="/api/prueba")
    assert client.get("/api/prueba/solo-admin", headers=_bearer("tok-admin")).status_code == 200
    resp = client.get("/api/prueba/solo-admin", headers=_bearer("tok-cliente"))
    assert resp.status_code == 403 and resp.get_json()["error"] == "sin_permiso"
    assert client.get("/api/prueba/solo-admin").status_code == 401
