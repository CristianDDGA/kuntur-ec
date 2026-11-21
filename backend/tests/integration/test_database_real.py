"""Pruebas contra la BD real de Supabase. Se omiten si no hay DATABASE_URL en backend/.env."""
import os

import pytest
from dotenv import load_dotenv

from database import Database
from models import TarifaIva, Usuario, Vuelo

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")

pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")


@pytest.fixture(scope="module")
def db():
    base = Database(URL)
    yield base
    base.cerrar()


def test_la_base_responde(db):
    assert db.disponible()


def test_las_filas_se_convierten_en_modelos(db):
    with db.transaccion() as cur:
        cur.execute("SELECT * FROM vuelos ORDER BY id LIMIT 1")
        vuelo = Vuelo.from_row(cur.fetchone())
        cur.execute("SELECT * FROM tarifas_iva WHERE vigente_hasta IS NULL")
        tarifa = TarifaIva.from_row(cur.fetchone())
        cur.execute("SELECT * FROM usuarios WHERE rol = 'admin' LIMIT 1")
        admin = Usuario.from_row(cur.fetchone())
    assert vuelo.capacidad > 0
    assert tarifa.porcentaje > 0
    assert admin.es_admin


def test_la_bd_impide_asientos_negativos(db):
    with pytest.raises(Exception), db.transaccion() as cur:
        cur.execute("UPDATE vuelos SET asientos_disponibles = -1 WHERE codigo = 'KT101'")


def test_registro_real_cifra_con_bcrypt_y_rechaza_correo_repetido(db):
    from services.usuario_service import UsuarioService
    from utils.excepciones import ConflictError
    from utils.seguridad import CifradorContrasenas

    servicio = UsuarioService(db, CifradorContrasenas(costo=4))
    correo = "prueba.automatica@kuntur.test"
    try:
        usuario = servicio.registrar({"nombre": "Prueba", "cedula": "1710034065", "correo": correo, "password": "Clave2026"})
        guardado = servicio.buscar_por_correo(correo.upper())
        assert guardado.id == usuario.id
        assert CifradorContrasenas().verificar("Clave2026", guardado.password_hash)
        with pytest.raises(ConflictError):
            servicio.registrar({"nombre": "Otra", "cedula": "1710034065", "correo": correo.upper(), "password": "Clave2026"})
    finally:
        with db.transaccion() as cur:
            cur.execute("DELETE FROM usuarios WHERE correo = %s", (correo,))


def test_una_cedula_solo_puede_tener_una_cuenta_en_la_base_real(db):
    from services.usuario_service import UsuarioService
    from utils.excepciones import ConflictError
    from utils.seguridad import CifradorContrasenas

    servicio = UsuarioService(db, CifradorContrasenas(costo=4))
    correos = ("cedula.uno@kuntur.test", "cedula.dos@kuntur.test")
    datos = {"nombre": "Prueba", "cedula": "1710034065", "password": "Clave2026"}
    try:
        servicio.registrar(datos | {"correo": correos[0]})
        with pytest.raises(ConflictError, match="esa cédula"):
            servicio.registrar(datos | {"correo": correos[1]})  # otro correo, misma cédula
        with pytest.raises(ConflictError, match="ese correo"):
            servicio.registrar(datos | {"correo": correos[0], "cedula": "0102030400"})  # misma cuenta, otra cédula
        assert servicio.buscar_por_correo(correos[0]).cedula == "1710034065"
    finally:
        with db.transaccion() as cur:
            cur.execute("DELETE FROM usuarios WHERE correo = ANY(%s)", (list(correos),))
