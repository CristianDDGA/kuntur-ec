import pytest

from tests.factories import un_usuario
from utils.excepciones import ConflictError, ValidationError

URL = "/api/usuarios/registro"


class ServicioUsuariosFalso:
    def __init__(self, error: Exception | None = None):
        self.error = error
        self.recibido = None

    def registrar(self, datos):
        self.recibido = datos
        if self.error:
            raise self.error
        return un_usuario(id=7, nombre=datos["nombre"], correo=datos["correo"])


@pytest.fixture
def servicio(app):
    falso = ServicioUsuariosFalso()
    app.extensions["usuario_service"] = falso
    return falso


def test_registro_exitoso_devuelve_201_sin_contrasena(client, servicio):
    resp = client.post(URL, json={"nombre": "Ana", "correo": "ana@correo.com", "password": "Clave2026"})
    assert resp.status_code == 201
    cuerpo = resp.get_json()
    assert cuerpo["mensaje"] == "Usuario registrado correctamente."
    assert cuerpo["usuario"]["id"] == 7
    assert "password_hash" not in cuerpo["usuario"]


def test_registro_responde_en_xml_si_se_solicita(client, servicio):
    resp = client.post(
        URL, json={"nombre": "Ana", "correo": "ana@correo.com", "password": "Clave2026"},
        headers={"Accept": "application/xml"},
    )
    assert resp.status_code == 201
    assert "<correo>ana@correo.com</correo>" in resp.get_data(as_text=True)


@pytest.mark.parametrize("cuerpo", [None, "texto", '["lista"]'])
def test_registro_sin_objeto_json_es_400(client, servicio, cuerpo):
    resp = client.post(URL, data=cuerpo, content_type="application/json")
    assert resp.status_code == 400
    assert resp.get_json()["error"] == "datos_invalidos"


@pytest.mark.parametrize(
    ("error", "status", "codigo"),
    [(ValidationError("x"), 400, "datos_invalidos"), (ConflictError("x"), 409, "conflicto")],
)
def test_registro_traduce_errores_del_servicio(client, app, error, status, codigo):
    app.extensions["usuario_service"] = ServicioUsuariosFalso(error)
    resp = client.post(URL, json={"nombre": "Ana", "correo": "a@b.com", "password": "Clave2026"})
    assert resp.status_code == status
    assert resp.get_json()["error"] == codigo
