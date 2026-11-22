"""Rutas de recuperación de contraseña (con servicio falso) y flujo completo contra la BD real."""
import os
import re

import pytest
from dotenv import load_dotenv

from app import create_app
from config import Settings
from database import Database
from utils.excepciones import ValidationError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")


class RecuperacionFalsa:
    def __init__(self):
        self.recibido = []

    def solicitar(self, datos):
        self.recibido.append(("solicitar", datos))
        return {"mensaje": "Si el correo está registrado, le enviamos un código para restablecer su contraseña."}

    def restablecer(self, datos):
        self.recibido.append(("restablecer", datos))
        if datos.get("codigo") == "000000":
            raise ValidationError("El código no es correcto o ya venció. Pida uno nuevo.")
        return {"mensaje": "Contraseña actualizada. Inicie sesión con la nueva contraseña."}


@pytest.fixture
def recuperacion(app):
    falso = RecuperacionFalsa()
    app.extensions["recuperacion_service"] = falso
    return falso


def test_recuperar_responde_200_y_es_publica(client, recuperacion):
    r = client.post("/api/auth/recuperar-clave", json={"correo": "ana@correo.com"})
    assert r.status_code == 200 and r.get_json()["mensaje"].startswith("Si el correo está registrado")
    assert recuperacion.recibido[0][0] == "solicitar"


def test_restablecer_responde_200_y_es_publica(client, recuperacion):
    r = client.post("/api/auth/restablecer-clave", json={"correo": "ana@correo.com", "codigo": "123456", "password": "Nueva2026"})
    assert r.status_code == 200 and "Contraseña actualizada" in r.get_json()["mensaje"]
    assert recuperacion.recibido[0][0] == "restablecer"


def test_un_codigo_malo_responde_400_con_el_mensaje(client, recuperacion):
    r = client.post("/api/auth/restablecer-clave", json={"correo": "ana@correo.com", "codigo": "000000", "password": "Nueva2026"})
    assert r.status_code == 400 and "no es correcto" in r.get_json()["mensaje"]


@pytest.mark.parametrize("ruta", ["/api/auth/recuperar-clave", "/api/auth/restablecer-clave"])
def test_sin_cuerpo_json_no_llega_al_servicio(client, recuperacion, ruta):
    assert client.post(ruta, data="x", headers={"Content-Type": "text/plain"}).status_code == 415
    assert recuperacion.recibido == []


@pytest.mark.parametrize("ruta", ["/api/auth/recuperar-clave", "/api/auth/restablecer-clave"])
def test_solo_se_acepta_post(client, recuperacion, ruta):
    assert client.get(ruta).status_code == 405


# ---------------------------------------------------------------- contra la BD real

pytestmark_real = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")
CORREO = "recuperacion.real@kuntur.test"
CLAVE_VIEJA = "ClaveVieja2026"
CLAVE_NUEVA = "ClaveNueva2026"


@pytest.fixture
def app_real():
    db = Database(URL)
    settings = Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas-suficientemente-larga-32b"})
    app = create_app(settings, db)
    app.extensions["enviador_correo"].enviados.clear()
    yield app
    with db.transaccion() as cur:
        cur.execute("DELETE FROM tokens WHERE usuario_id IN (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
        cur.execute("DELETE FROM usuarios WHERE correo = %s", (CORREO,))  # los códigos caen por ON DELETE CASCADE
    db.cerrar()


def _crear_cuenta_verificada(c, app):
    """Registra y verifica la cuenta de prueba; deja la bandeja del enviador vacía."""
    c.post("/api/usuarios/registro", json={"nombre": "Prueba Real", "cedula": "1710034065", "correo": CORREO, "password": CLAVE_VIEJA})
    codigo = re.search(r"\b(\d{6})\b", app.extensions["enviador_correo"].enviados[-1][2]).group(1)
    assert c.post("/api/auth/verificar-correo", json={"correo": CORREO, "codigo": codigo}).status_code == 200
    app.extensions["enviador_correo"].enviados.clear()


def _codigo_enviado(app):
    return re.search(r"\b(\d{6})\b", app.extensions["enviador_correo"].enviados[-1][2]).group(1)


def _login(c, password):
    return c.post("/api/auth/login", json={"correo": CORREO, "password": password})


@pytestmark_real
def test_flujo_completo_olvido_codigo_nueva_clave_y_sesiones_cerradas(app_real):
    c = app_real.test_client()
    _crear_cuenta_verificada(c, app_real)
    token_viejo = _login(c, CLAVE_VIEJA).get_json()["token"]
    cabecera = {"Authorization": f"Bearer {token_viejo}"}
    assert c.get("/api/auth/perfil", headers=cabecera).status_code == 200

    # 1) Pide el código: llega por correo y la respuesta no cambia.
    r = c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    assert r.status_code == 200 and len(app_real.extensions["enviador_correo"].enviados) == 1
    codigo = _codigo_enviado(app_real)

    # 2) Un código equivocado no cambia nada y cuenta el intento; la clave vieja sigue sirviendo.
    malo = "000000" if codigo != "000000" else "111111"
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": malo, "password": CLAVE_NUEVA})
    assert r.status_code == 400 and "Le quedan 4 intentos" in r.get_json()["mensaje"]
    assert _login(c, CLAVE_VIEJA).status_code == 200

    # 3) Una clave floja no gasta un intento ni cambia nada.
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": codigo, "password": "corta"})
    assert r.status_code == 400 and "al menos 8" in r.get_json()["mensaje"]

    # 4) El código correcto cambia la clave.
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": codigo, "password": CLAVE_NUEVA})
    assert r.status_code == 200
    assert _login(c, CLAVE_VIEJA).status_code == 401
    assert _login(c, CLAVE_NUEVA).status_code == 200

    # 5) La sesión que estaba abierta quedó cerrada.
    assert c.get("/api/auth/perfil", headers=cabecera).status_code == 401

    # 6) El código no se puede reutilizar.
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": codigo, "password": "OtraClave2026"})
    assert r.status_code == 400 and "no es correcto o ya venció" in r.get_json()["mensaje"]


@pytestmark_real
def test_pedir_el_codigo_para_una_cuenta_que_no_existe_responde_igual_y_no_envia_nada(app_real):
    c = app_real.test_client()
    r = c.post("/api/auth/recuperar-clave", json={"correo": "nadie.existe@kuntur.test"})
    assert r.status_code == 200 and r.get_json()["mensaje"].startswith("Si el correo está registrado")
    assert app_real.extensions["enviador_correo"].enviados == []
    r = c.post("/api/auth/restablecer-clave", json={"correo": "nadie.existe@kuntur.test", "codigo": "123456", "password": CLAVE_NUEVA})
    assert r.status_code == 400 and "no es correcto o ya venció" in r.get_json()["mensaje"]


@pytestmark_real
def test_cinco_intentos_fallidos_invalidan_el_codigo_y_un_reenvio_lo_reemplaza(app_real):
    c = app_real.test_client()
    _crear_cuenta_verificada(c, app_real)
    c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    primero = _codigo_enviado(app_real)
    malo = "000000" if primero != "000000" else "111111"
    for _ in range(5):
        assert c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": malo, "password": CLAVE_NUEVA}).status_code == 400
    # Agotados los intentos: ni el código correcto sirve.
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": primero, "password": CLAVE_NUEVA})
    assert r.status_code == 400 and "no es correcto o ya venció" in r.get_json()["mensaje"]
    assert _login(c, CLAVE_VIEJA).status_code == 200

    # Pedir otro antes de 60 s no envía nada; pasado el tiempo sí, y reemplaza al anterior.
    c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    assert len(app_real.extensions["enviador_correo"].enviados) == 1
    with app_real.extensions["db"].transaccion() as cur:
        cur.execute(
            "UPDATE codigos_recuperacion SET enviado_en = now() - interval '2 minutes' "
            "WHERE usuario_id = (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
    c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    assert len(app_real.extensions["enviador_correo"].enviados) == 2
    nuevo = _codigo_enviado(app_real)
    assert c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": nuevo, "password": CLAVE_NUEVA}).status_code == 200


@pytestmark_real
def test_un_codigo_vencido_no_sirve(app_real):
    c = app_real.test_client()
    _crear_cuenta_verificada(c, app_real)
    c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    codigo = _codigo_enviado(app_real)
    with app_real.extensions["db"].transaccion() as cur:
        cur.execute(
            "UPDATE codigos_recuperacion SET expira = now() - interval '1 second' "
            "WHERE usuario_id = (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
    r = c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": codigo, "password": CLAVE_NUEVA})
    assert r.status_code == 400 and "ya venció" in r.get_json()["mensaje"]


@pytestmark_real
def test_restablecer_verifica_una_cuenta_que_nunca_confirmo_su_correo(app_real):
    """El código llegó a su correo: eso prueba que es suyo, así que la cuenta queda verificada."""
    c = app_real.test_client()
    c.post("/api/usuarios/registro", json={"nombre": "Prueba Real", "cedula": "1710034065", "correo": CORREO, "password": CLAVE_VIEJA})
    assert _login(c, CLAVE_VIEJA).status_code == 403  # sin verificar no entra
    app_real.extensions["enviador_correo"].enviados.clear()

    c.post("/api/auth/recuperar-clave", json={"correo": CORREO})
    codigo = _codigo_enviado(app_real)
    assert c.post("/api/auth/restablecer-clave", json={"correo": CORREO, "codigo": codigo, "password": CLAVE_NUEVA}).status_code == 200
    r = _login(c, CLAVE_NUEVA)
    assert r.status_code == 200 and r.get_json()["usuario"]["correo_verificado"] is True
