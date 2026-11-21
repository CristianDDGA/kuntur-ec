import pytest

from models import Avion
from tests.integration.test_vuelos import AuthFalso, _bearer
from utils.excepciones import ValidationError

CSV = "matricula;modelo;filas\nHC-ABC;Airbus A320;30\n"


class AvionesFalso:
    def __init__(self):
        self.recibido = None

    def listar(self):
        return [Avion(id=1, matricula="HC-ABC", modelo="A320", filas=30)]

    def validar(self, contenido):
        self.recibido = contenido
        return {"total_filas": 1, "nuevos": 1, "existentes": [], "con_errores": 0, "errores": [], "vista_previa": []}

    def importar(self, contenido):
        self.recibido = contenido
        if b"MAL" in contenido:
            raise ValidationError("El archivo tiene filas con errores.", errores=[{"linea": 2, "mensaje": "x"}])
        return {"creados": 1, "omitidos": [], "total_filas": 1}


@pytest.fixture
def aviones(app):
    falso = AvionesFalso()
    app.extensions.update(avion_service=falso, auth_service=AuthFalso())
    return falso


def _csv(client, ruta, cuerpo=CSV, token="tok-admin", tipo="text/csv"):
    return client.post(ruta, data=cuerpo.encode(), headers=_bearer(token) | {"Content-Type": tipo})


def test_listar_devuelve_la_capacidad(client, aviones):
    r = client.get("/api/aviones", headers=_bearer("tok-admin"))
    assert r.status_code == 200 and r.get_json()["aviones"][0]["capacidad"] == 120


def test_importar_pasa_el_archivo_al_servicio_y_responde_201(client, aviones):
    r = _csv(client, "/api/aviones/importacion")
    assert r.status_code == 201 and r.get_json()["creados"] == 1
    assert aviones.recibido == CSV.encode()


def test_validar_responde_200(client, aviones):
    assert _csv(client, "/api/aviones/importacion/validar").status_code == 200


def test_importar_con_errores_devuelve_400_con_la_lista_por_linea(client, aviones):
    r = _csv(client, "/api/aviones/importacion", "matricula;modelo;filas\nMAL")
    assert r.status_code == 400 and r.get_json()["errores"][0]["linea"] == 2


@pytest.mark.parametrize("ruta", ["/api/aviones/importacion", "/api/aviones/importacion/validar"])
def test_solo_el_administrador_importa(client, aviones, ruta):
    assert _csv(client, ruta, token="tok-cliente").status_code == 403
    assert client.post(ruta, data=CSV.encode(), headers={"Content-Type": "text/csv"}).status_code == 401


def test_un_cliente_no_lista_aviones(client, aviones):
    assert client.get("/api/aviones", headers=_bearer("tok-cliente")).status_code == 403


def test_un_cuerpo_que_no_es_csv_responde_415(client, aviones):
    assert _csv(client, "/api/aviones/importacion", tipo="application/json").status_code == 415


def test_un_archivo_mayor_a_1_mb_responde_413(client, aviones):
    grande = "matricula;modelo;filas\n" + "x" * (1024 * 1024 + 10)
    assert _csv(client, "/api/aviones/importacion", grande).status_code == 413
