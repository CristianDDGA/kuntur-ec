import pytest

from app import create_app


def test_health_responde_json_por_defecto(client):
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.mimetype == "application/json"
    assert resp.get_json()["estado"] == "ok"


def test_health_responde_xml_si_se_solicita(client):
    resp = client.get("/api/health", headers={"Accept": "application/xml"})
    assert resp.status_code == 200
    assert resp.mimetype == "application/xml"
    assert "<estado>ok</estado>" in resp.get_data(as_text=True)


def test_ruta_inexistente_devuelve_error_uniforme_en_espanol(client):
    resp = client.get("/api/no-existe")
    assert resp.status_code == 404
    assert resp.get_json() == {
        "error": "no_encontrado",
        "mensaje": "El recurso solicitado no existe.",
    }


def test_metodo_no_permitido(client):
    resp = client.post("/api/health")
    assert resp.status_code == 405
    assert resp.get_json()["error"] == "metodo_no_permitido"


class _BaseDatosFalsa:
    def __init__(self, responde: bool):
        self.responde = responde

    def disponible(self) -> bool:
        return self.responde


def test_health_sin_base_de_datos_configurada(client):
    assert client.get("/api/health").get_json()["base_datos"] == "sin_configurar"


@pytest.mark.parametrize(("responde", "estado"), [(True, "conectada"), (False, "no_disponible")])
def test_health_informa_el_estado_de_la_base_de_datos(settings, responde, estado):
    app = create_app(settings, db=_BaseDatosFalsa(responde))
    assert app.test_client().get("/api/health").get_json()["base_datos"] == estado
