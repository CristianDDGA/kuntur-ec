"""Errores HTTP conocidos y fallos de servidor: siempre una respuesta controlada, nunca detalles internos."""
import psycopg
import pytest
from psycopg import errors as pg

from app import create_app
from tests.factories import un_usuario, un_vuelo
from utils.excepciones import ServiceUnavailableError, TooManyRequestsError

REGISTRO = "/api/usuarios/registro"
DATOS = {"nombre": "Ana Torres", "correo": "ana@correo.com", "password": "Clave2026"}
SECRETO = "tabla usuarios SELECT password_hash psycopg Traceback"


class UsuariosFalso:
    def __init__(self, error=None):
        self.error = error
        self.llamadas = 0

    def registrar(self, datos):
        self.llamadas += 1
        if self.error:
            raise self.error
        return un_usuario(nombre=datos["nombre"], correo=datos["correo"])


@pytest.fixture
def usuarios(app):
    falso = UsuariosFalso()
    app.extensions["usuario_service"] = falso
    return falso


def _error(resp):
    cuerpo = resp.get_json()
    assert set(cuerpo) >= {"error", "mensaje"}
    return cuerpo


def _sin_filtraciones(resp):
    texto = resp.get_data(as_text=True)
    for pista in ("Traceback", "psycopg", "SELECT", "INSERT", "File \"", "Internal Server Error", "<html", "secreto"):
        assert pista not in texto


# ---------------------------------------------------------------- 400 / 413 / 415


def test_413_cuerpo_demasiado_grande(client, usuarios):
    resp = client.post(REGISTRO, data='{"nombre": "' + "A" * 200_000 + '"}', content_type="application/json")
    assert resp.status_code == 413
    assert _error(resp)["error"] == "cuerpo_demasiado_grande"
    assert usuarios.llamadas == 0


@pytest.mark.parametrize("tipo", ["text/plain", "application/x-www-form-urlencoded", "application/xml"])
def test_415_si_el_cuerpo_no_es_json(client, usuarios, tipo):
    resp = client.post(REGISTRO, data='{"nombre": "Ana"}', content_type=tipo)
    assert resp.status_code == 415
    assert _error(resp)["error"] == "formato_no_soportado"


def test_sin_cuerpo_ni_tipo_es_400(client, usuarios):
    resp = client.post(REGISTRO)
    assert resp.status_code == 400 and _error(resp)["error"] == "datos_invalidos"


@pytest.mark.parametrize(
    "cuerpo",
    ['{"nombre": "Ana",', "[1, 2, 3]", '"texto"', "null", "[" * 5000 + "]" * 5000, '{"a":{"b":{"c":{"d":{"e":{"f":1}}}}}}',
     '{"password": NaN}', '{"password": Infinity}', '{"nombre": "Ana\\u0000"}', '{"nombre": "Ana\\nTorres"}'],
    ids=["malformado", "lista", "texto", "null", "anidado-5000", "profundo", "NaN", "Infinity", "NUL", "salto-de-linea"],
)
def test_400_cuerpos_invalidos_nunca_llegan_al_servicio(client, usuarios, cuerpo):
    resp = client.post(REGISTRO, data=cuerpo, content_type="application/json")
    assert resp.status_code == 400
    assert _error(resp)["error"] == "datos_invalidos"
    assert usuarios.llamadas == 0
    _sin_filtraciones(resp)


# ---------------------------------------------------------------- 404 / 405 / ids


@pytest.mark.parametrize(
    "ruta", ["/api/vuelos/99999999999999999999", "/api/vuelos/-1", "/api/vuelos/0", "/api/vuelos/007", "/api/reservas/1e5",
             "/api/reservas/99999999999999999999/comprobante", "/api/vuelos/abc"],
)
def test_404_ids_fuera_de_rango_o_mal_escritos(client, ruta):
    resp = client.get(ruta)
    assert resp.status_code == 404 and _error(resp)["error"] == "no_encontrado"


def test_id_valido_llega_al_servicio(app, client):
    class Vuelos:
        def obtener(self, vuelo_id):
            return un_vuelo(id=vuelo_id)

    app.extensions["vuelo_service"] = Vuelos()
    assert client.get("/api/vuelos/10").get_json()["id"] == 10
    assert client.get("/api/vuelos/999999999999999999").status_code == 200  # el mayor id aceptado (18 dígitos)


def test_405_metodo_no_permitido(client):
    resp = client.patch("/api/vuelos")
    assert resp.status_code == 405 and _error(resp)["error"] == "metodo_no_permitido"


# ---------------------------------------------------------------- 429


def test_429_incluye_retry_after(app, client):
    class Auth:
        def login(self, datos, origen=""):
            raise TooManyRequestsError("Demasiados intentos fallidos.", reintentar_en_segundos=120)

    app.extensions["auth_service"] = Auth()
    resp = client.post("/api/auth/login", json={"correo": "a@b.com", "password": "x"})
    assert resp.status_code == 429
    assert resp.headers["Retry-After"] == "120"
    assert _error(resp)["error"] == "demasiados_intentos"
    assert resp.get_json()["reintentar_en_segundos"] == 120


# ---------------------------------------------------------------- 503 y errores de base de datos


def test_503_cuando_la_base_no_responde(app, client):
    app.extensions["usuario_service"] = UsuariosFalso(ServiceUnavailableError("x", reintentar_en_segundos=5))
    resp = client.post(REGISTRO, json=DATOS)
    assert resp.status_code == 503
    assert resp.headers["Retry-After"] == "5"
    assert _error(resp)["error"] == "servicio_no_disponible"


@pytest.mark.parametrize(
    ("excepcion", "status", "codigo", "mensaje"),
    [
        (pg.NumericValueOutOfRange(SECRETO), 400, "datos_invalidos", "Los datos enviados no son válidos."),
        (pg.StringDataRightTruncation(SECRETO), 400, "datos_invalidos", "Los datos enviados no son válidos."),
        (pg.CheckViolation(SECRETO), 409, "conflicto", "La operación entra en conflicto con los datos existentes."),
        (pg.ForeignKeyViolation(SECRETO), 409, "conflicto", "La operación entra en conflicto con los datos existentes."),
        (psycopg.OperationalError(SECRETO), 503, "servicio_no_disponible", None),
        (psycopg.InterfaceError(SECRETO), 503, "servicio_no_disponible", None),
        (pg.DeadlockDetected(SECRETO), 503, "servicio_no_disponible", None),
    ],
)
def test_errores_de_postgres_no_previstos_se_traducen_sin_filtrar_detalles(app, client, excepcion, status, codigo, mensaje):
    app.extensions["usuario_service"] = UsuariosFalso(excepcion)
    resp = client.post(REGISTRO, json=DATOS)
    assert resp.status_code == status
    assert _error(resp)["error"] == codigo
    if mensaje:
        assert resp.get_json()["mensaje"] == mensaje
    assert "usuarios" not in resp.get_data(as_text=True) and "password_hash" not in resp.get_data(as_text=True)
    _sin_filtraciones(resp)


# ---------------------------------------------------------------- 500


@pytest.mark.parametrize("excepcion", [RuntimeError("secreto"), KeyError("secreto"), ZeroDivisionError("secreto"),
                                         AttributeError("secreto"), MemoryError("secreto")])
def test_500_inesperado_responde_generico_sin_detalles(app, client, excepcion):
    app.extensions["usuario_service"] = UsuariosFalso(excepcion)
    resp = client.post(REGISTRO, json=DATOS)
    assert resp.status_code == 500
    assert resp.get_json() == {"error": "error_interno", "mensaje": "Ocurrió un error inesperado."}


def test_500_tambien_se_responde_en_xml(app, client):
    app.extensions["usuario_service"] = UsuariosFalso(RuntimeError("secreto"))
    resp = client.post(REGISTRO, json=DATOS, headers={"Accept": "application/xml"})
    assert resp.status_code == 500 and resp.mimetype == "application/xml"
    assert "<error>error_interno</error>" in resp.get_data(as_text=True)
    _sin_filtraciones(resp)


def test_500_en_una_ruta_nueva_sin_try_except(settings):
    """Cualquier función que falle, aunque no tenga try/except, termina en el 500 genérico."""
    app = create_app(settings)

    @app.route("/api/_prueba_explota")
    def explota():
        raise RuntimeError("detalle interno secreto")

    resp = app.test_client().get("/api/_prueba_explota")
    assert resp.status_code == 500
    _sin_filtraciones(resp)


# ---------------------------------------------------------------- cabeceras


def test_cabeceras_de_seguridad_en_las_respuestas_de_la_api(client):
    resp = client.get("/api/health")
    assert resp.headers["X-Content-Type-Options"] == "nosniff"
    assert resp.headers["Cache-Control"] == "no-store"


def test_las_respuestas_de_error_tambien_llevan_las_cabeceras(client):
    resp = client.get("/api/no-existe")
    assert resp.headers["X-Content-Type-Options"] == "nosniff"
    assert resp.headers["Cache-Control"] == "no-store"
