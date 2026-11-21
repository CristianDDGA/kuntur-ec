"""Rutas de verificación del correo (con servicios falsos) y flujo completo contra la BD real."""
import os
import re

import pytest
from dotenv import load_dotenv

from app import create_app
from config import Settings
from database import Database
from utils.correo import EnviadorLocal
from utils.excepciones import ValidationError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")


class VerificacionFalsa:
    def __init__(self):
        self.recibido = []

    def verificar(self, datos):
        self.recibido.append(("verificar", datos))
        if datos.get("codigo") == "000000":
            raise ValidationError("El código no es correcto o ya venció. Pida uno nuevo.")
        return {"correo": datos["correo"]}

    def reenviar(self, datos):
        self.recibido.append(("reenviar", datos))
        return {"mensaje": "Si la cuenta existe y falta verificarla, le enviamos un código nuevo."}


@pytest.fixture
def verificacion(app):
    falso = VerificacionFalsa()
    app.extensions["verificacion_service"] = falso
    return falso


def test_verificar_responde_200_y_es_publica(client, verificacion):
    r = client.post("/api/auth/verificar-correo", json={"correo": "ana@correo.com", "codigo": "123456"})
    assert r.status_code == 200 and r.get_json()["correo"] == "ana@correo.com"
    assert verificacion.recibido[0][0] == "verificar"


def test_un_codigo_malo_responde_400_con_el_mensaje(client, verificacion):
    r = client.post("/api/auth/verificar-correo", json={"correo": "ana@correo.com", "codigo": "000000"})
    assert r.status_code == 400 and "no es correcto" in r.get_json()["mensaje"]


def test_reenviar_responde_200_igual_para_cualquier_correo(client, verificacion):
    r = client.post("/api/auth/reenviar-codigo", json={"correo": "nadie@correo.com"})
    assert r.status_code == 200 and r.get_json()["mensaje"].startswith("Si la cuenta existe")


@pytest.mark.parametrize("ruta", ["/api/auth/verificar-correo", "/api/auth/reenviar-codigo"])
def test_sin_cuerpo_json_no_llega_al_servicio(client, verificacion, ruta):
    assert client.post(ruta, data="x", headers={"Content-Type": "text/plain"}).status_code == 415
    assert verificacion.recibido == []


# ---------------------------------------------------------------- contra la BD real

pytestmark_real = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")
CORREO = "verificacion.real@kuntur.test"


@pytest.fixture
def app_real():
    db = Database(URL)
    settings = Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas-suficientemente-larga-32b"})
    app = create_app(settings, db)
    app.extensions["enviador_correo"].enviados.clear()
    yield app
    with db.transaccion() as cur:
        cur.execute("DELETE FROM tokens WHERE usuario_id IN (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
        cur.execute("DELETE FROM usuarios WHERE correo = %s", (CORREO,))
    db.cerrar()


def _codigo_enviado(app):
    enviador: EnviadorLocal = app.extensions["enviador_correo"]
    return re.search(r"\b(\d{6})\b", enviador.enviados[-1][2]).group(1)


@pytestmark_real
def test_flujo_completo_registro_codigo_verificacion_y_login(app_real):
    c = app_real.test_client()
    datos = {"nombre": "Prueba Real", "cedula": "1710034065", "correo": CORREO, "password": "Clave2026"}

    r = c.post("/api/usuarios/registro", json=datos)
    assert r.status_code == 201 and r.get_json()["verificacion_pendiente"] and r.get_json()["codigo_enviado"]
    assert len(app_real.extensions["enviador_correo"].enviados) == 1
    codigo = _codigo_enviado(app_real)

    # 1) Sin verificar no puede entrar, y el error dice por qué.
    r = c.post("/api/auth/login", json={"correo": CORREO, "password": "Clave2026"})
    assert r.status_code == 403 and r.get_json()["error"] == "correo_no_verificado"
    assert r.get_json()["correo"] == CORREO

    # 2) Un código equivocado no verifica y cuenta el intento.
    malo = "000000" if codigo != "000000" else "111111"
    r = c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": malo})
    assert r.status_code == 400 and "Le quedan 4 intentos" in r.get_json()["mensaje"]
    assert c.post("/api/auth/login", json={"correo": CORREO, "password": "Clave2026"}).status_code == 403

    # 3) El código correcto verifica; después entra.
    assert c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": codigo}).status_code == 200
    r = c.post("/api/auth/login", json={"correo": CORREO, "password": "Clave2026"})
    assert r.status_code == 200 and r.get_json()["usuario"]["correo_verificado"] is True

    # 4) El código no se puede reutilizar.
    assert c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": codigo}).status_code == 400


@pytestmark_real
def test_cinco_intentos_fallidos_invalidan_el_codigo_y_un_reenvio_lo_reemplaza(app_real):
    c = app_real.test_client()
    c.post("/api/usuarios/registro", json={"nombre": "Prueba Real", "cedula": "1710034065", "correo": CORREO, "password": "Clave2026"})
    primero = _codigo_enviado(app_real)
    malo = "000000" if primero != "000000" else "111111"

    for _ in range(5):
        assert c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": malo}).status_code == 400
    # Agotados los intentos: ni el código correcto sirve.
    r = c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": primero})
    assert r.status_code == 400 and "no es correcto o ya venció" in r.get_json()["mensaje"]

    # Pedir otro antes de 60 s no envía nada (y responde igual).
    r = c.post("/api/auth/reenviar-codigo", json={"correo": CORREO})
    assert r.status_code == 200 and len(app_real.extensions["enviador_correo"].enviados) == 1

    # Pasados los 60 s se envía uno nuevo, que reemplaza al anterior y reinicia los intentos.
    db = app_real.extensions["db"]
    with db.transaccion() as cur:
        cur.execute(
            "UPDATE codigos_verificacion SET enviado_en = now() - interval '2 minutes' "
            "WHERE usuario_id = (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
    assert c.post("/api/auth/reenviar-codigo", json={"correo": CORREO}).status_code == 200
    assert len(app_real.extensions["enviador_correo"].enviados) == 2
    nuevo = _codigo_enviado(app_real)
    assert c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": nuevo}).status_code == 200


@pytestmark_real
def test_un_codigo_vencido_no_sirve(app_real):
    c = app_real.test_client()
    c.post("/api/usuarios/registro", json={"nombre": "Prueba Real", "cedula": "1710034065", "correo": CORREO, "password": "Clave2026"})
    codigo = _codigo_enviado(app_real)
    with app_real.extensions["db"].transaccion() as cur:
        cur.execute(
            "UPDATE codigos_verificacion SET expira = now() - interval '1 second' "
            "WHERE usuario_id = (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
    r = c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": codigo})
    assert r.status_code == 400 and "ya venció" in r.get_json()["mensaje"]
