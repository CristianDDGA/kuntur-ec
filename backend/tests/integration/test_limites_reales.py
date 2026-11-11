"""Guarda en la BD real los valores en su tamaño MÁXIMO: la base debe aceptarlos todos.

Demuestra que los límites del código son exactamente los de las columnas (ni uno más, ni uno menos).
"""
import os
from datetime import date, timedelta

import pytest
from dotenv import load_dotenv

from database import Database
from services.usuario_service import UsuarioService
from services.vuelo_service import VueloService
from utils import limites
from utils.excepciones import ValidationError
from utils.seguridad import CifradorContrasenas

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

# 64 + 1 + 63 + 1 + 17 + 4 = 150 caracteres exactos (local ≤ 64 y etiquetas ≤ 63 por norma)
CORREO_MAXIMO = "a" * 64 + "@" + "b" * 63 + "." + "d" * 17 + ".com"
CODIGO = "K" * limites.CODIGO_VUELO


@pytest.fixture
def db():
    base = Database(URL)
    yield base
    with base.transaccion() as cur:
        cur.execute("DELETE FROM vuelos WHERE codigo = %s", (CODIGO,))
        cur.execute("DELETE FROM usuarios WHERE correo = %s", (CORREO_MAXIMO,))
    base.cerrar()


def test_el_correo_de_prueba_mide_exactamente_el_limite():
    assert len(CORREO_MAXIMO) == limites.CORREO == 150


def test_la_base_acepta_nombre_correo_codigo_y_ciudades_en_su_largo_maximo(db):
    usuario = UsuarioService(db, CifradorContrasenas(costo=4)).registrar(
        {"nombre": "A" * limites.NOMBRE_PERSONA, "correo": CORREO_MAXIMO, "password": "Clave2026"}
    )
    assert len(usuario.nombre) == 100 and len(usuario.correo) == 150

    vuelo = VueloService(db).crear({
        "codigo": CODIGO, "origen": "Q" * limites.CIUDAD, "destino": "Z" * limites.CIUDAD,
        "fecha": (date.today() + timedelta(days=30)).isoformat(), "hora_salida": "08:00", "hora_llegada": "09:00",
        "precio": limites.PRECIO_MAXIMO, "capacidad": limites.CAPACIDAD_MAXIMA,
    })
    assert (len(vuelo.codigo), len(vuelo.origen), len(vuelo.destino)) == (10, 80, 80)
    assert vuelo.capacidad == 200 and str(vuelo.precio) == "10000.00"


@pytest.mark.parametrize(
    ("datos", "campo"),
    [({"nombre": "A" * 101}, "nombre"), ({"correo": "a" * 64 + "@" + "b" * 63 + "." + "d" * 18 + ".com"}, "correo")],
)
def test_un_caracter_mas_que_el_limite_se_rechaza_antes_de_llegar_a_la_base(db, datos, campo):
    base = {"nombre": "Ana Torres", "correo": "limite@kuntur.test", "password": "Clave2026"}
    with pytest.raises(ValidationError, match=campo):
        UsuarioService(db, CifradorContrasenas(costo=4)).registrar(base | datos)


def test_ciudad_y_codigo_un_caracter_mas_se_rechazan(db):
    nuevo = {
        "codigo": "KT801", "origen": "Quito", "destino": "Loja", "fecha": (date.today() + timedelta(days=30)).isoformat(),
        "hora_salida": "08:00", "hora_llegada": "09:00", "precio": 50, "capacidad": 10,
    }
    servicio = VueloService(db)
    for cambio, texto in (({"codigo": "K" * 11}, "10 caracteres"), ({"origen": "Q" * 81}, "80 caracteres"),
                          ({"destino": "Z" * 81}, "80 caracteres")):
        with pytest.raises(ValidationError, match=texto):
            servicio.crear(nuevo | cambio)
