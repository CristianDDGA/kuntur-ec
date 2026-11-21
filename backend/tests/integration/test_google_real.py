"""Inicio de sesión con Google y cédula contra la BD real (el token de Google se simula con un verificador falso)."""
import os

import pytest
from dotenv import load_dotenv

from app import create_app
from config import Settings
from database import Database
from services.auth_service import AuthService
from services.usuario_service import UsuarioService
from tests.unit.test_google import VerificadorFalso
from utils.google import IdentidadGoogle
from utils.seguridad import CifradorContrasenas, EmisorTokens

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

CORREOS = ("google.real@kuntur.test", "google.dos@kuntur.test")
emisor = EmisorTokens("clave-de-pruebas-suficientemente-larga-32b", 60)


@pytest.fixture
def db():
    base = Database(URL)
    _limpiar(base)
    yield base
    _limpiar(base)
    base.cerrar()


def _limpiar(db):
    with db.transaccion() as cur:
        cur.execute("DELETE FROM tokens WHERE usuario_id IN (SELECT id FROM usuarios WHERE correo = ANY(%s))", (list(CORREOS),))
        cur.execute("DELETE FROM usuarios WHERE correo = ANY(%s)", (list(CORREOS),))


def _servicios(db, identidad):
    usuarios = UsuarioService(db, CifradorContrasenas(costo=4))
    auth = AuthService(db, usuarios, emisor, CifradorContrasenas(costo=4), verificador_google=VerificadorFalso(identidad))
    return usuarios, auth


def test_primer_ingreso_crea_la_cuenta_verificada_sin_cedula_y_el_segundo_la_reconoce(db):
    identidad = IdentidadGoogle(sub="sub-real-1", correo=CORREOS[0], nombre="Ana Google")
    usuarios, auth = _servicios(db, identidad)

    primero = auth.login_google({"id_token": "t"})
    assert primero["nuevo"] is True
    u = primero["usuario"]
    assert (u["nombre"], u["correo"], u["rol"], u["cedula"], u["correo_verificado"]) == ("Ana Google", CORREOS[0], "cliente", None, True)

    segundo = auth.login_google({"id_token": "t"})
    assert segundo["nuevo"] is False and segundo["usuario"]["id"] == u["id"]  # misma cuenta, no se duplica
    assert emisor.leer(segundo["token"]).usuario_id == u["id"]


def test_la_cuenta_de_google_no_se_puede_usar_con_contrasena(db):
    usuarios, auth = _servicios(db, IdentidadGoogle("sub-real-2", CORREOS[0], "Ana"))
    auth.login_google({"id_token": "t"})
    from utils.excepciones import UnauthorizedError

    for clave in ("", "Clave2026", "cualquiera12345"):
        with pytest.raises(UnauthorizedError):
            auth.login({"correo": CORREOS[0], "password": clave or "x"})


def test_una_cuenta_con_correo_y_contrasena_se_vincula_y_queda_verificada(db):
    usuarios, auth = _servicios(db, IdentidadGoogle("sub-real-3", CORREOS[0], "Ana Google"))
    creada = usuarios.registrar({"nombre": "Ana Torres", "cedula": "1710034065", "correo": CORREOS[0], "password": "Clave2026"})
    assert creada.correo_verificado is False  # el registro con contraseña nace sin verificar

    r = auth.login_google({"id_token": "t"})
    assert r["nuevo"] is False and r["usuario"]["id"] == creada.id
    assert r["usuario"]["correo_verificado"] is True and r["usuario"]["cedula"] == "1710034065"  # conserva sus datos
    assert r["usuario"]["nombre"] == "Ana Torres"  # y su nombre (no lo pisa Google)
    # La contraseña original sigue sirviendo.
    assert auth.login({"correo": CORREOS[0], "password": "Clave2026"})["usuario"]["id"] == creada.id


def test_otra_cuenta_de_google_con_el_mismo_correo_no_toma_la_cuenta(db):
    from utils.excepciones import ConflictError

    usuarios, auth = _servicios(db, IdentidadGoogle("sub-real-4", CORREOS[0], "Ana"))
    auth.login_google({"id_token": "t"})
    _, otra = _servicios(db, IdentidadGoogle("sub-OTRA", CORREOS[0], "Intruso"))
    with pytest.raises(ConflictError, match="otra cuenta de Google"):
        otra.login_google({"id_token": "t"})


def test_completar_la_cedula_valida_es_unica_y_no_se_cambia(db):
    from utils.excepciones import ConflictError, ValidationError

    usuarios, auth = _servicios(db, IdentidadGoogle("sub-real-5", CORREOS[0], "Ana"))
    uid = auth.login_google({"id_token": "t"})["usuario"]["id"]

    with pytest.raises(ValidationError, match="no es válida"):
        usuarios.completar_cedula(uid, {"cedula": "1710034066"})
    assert usuarios.completar_cedula(uid, {"cedula": "1710034065"}).cedula == "1710034065"
    with pytest.raises(ConflictError, match="no se puede cambiar"):
        usuarios.completar_cedula(uid, {"cedula": "0102030400"})

    # otra cuenta no puede quedarse con esa cédula
    _, otra = _servicios(db, IdentidadGoogle("sub-real-6", CORREOS[1], "Beto"))
    otro_id = otra.login_google({"id_token": "t"})["usuario"]["id"]
    with pytest.raises(ConflictError, match="esa cédula"):
        usuarios.completar_cedula(otro_id, {"cedula": "1710034065"})


def test_la_ruta_http_sin_client_id_responde_503_y_con_token_falso_401(db):
    settings = Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas-suficientemente-larga-32b"})
    app = create_app(settings, db)
    r = app.test_client().post("/api/auth/google", json={"id_token": "x"})
    assert r.status_code == 503  # sin GOOGLE_CLIENT_ID

    settings = Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas-suficientemente-larga-32b",
                                  "GOOGLE_CLIENT_ID": "123.apps.googleusercontent.com"})
    app = create_app(settings, db)
    r = app.test_client().post("/api/auth/google", json={"id_token": "no.es.un.jwt"})
    assert r.status_code == 401  # un token inventado no entra (la librería lo rechaza antes de contactar a Google)
