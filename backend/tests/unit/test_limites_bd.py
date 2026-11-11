"""Los límites del código deben ser EXACTAMENTE los de las columnas de la base de datos.

Si en schema.sql una columna es VARCHAR(200), el código solo debe aceptar hasta 200
caracteres: ni uno más (daría un error 500 al guardar) ni uno menos (rechazaría datos válidos).
"""
import os
import re

import pytest
from dotenv import load_dotenv

from database import CARPETA_SQL, Database
from models import EstadoReserva, EstadoToken, Rol
from utils import limites

# (tabla, columna) de tipo VARCHAR que el usuario escribe -> límite que aplica el código
LIMITES_DE_ENTRADA = {
    ("usuarios", "nombre"): limites.NOMBRE_PERSONA,
    ("usuarios", "correo"): limites.CORREO,
    ("vuelos", "codigo"): limites.CODIGO_VUELO,
    ("vuelos", "origen"): limites.CIUDAD,
    ("vuelos", "destino"): limites.CIUDAD,
    ("reserva_asientos", "asiento"): limites.ASIENTO,
}
# VARCHAR que NO escribe el usuario: los llena el sistema con valores controlados.
VARCHAR_INTERNOS = {
    ("usuarios", "password_hash"), ("usuarios", "rol"), ("reservas", "estado"), ("tokens", "estado"),
}


def _varchar_de_schema() -> dict[tuple[str, str], int]:
    sql = (CARPETA_SQL / "schema.sql").read_text(encoding="utf-8")
    columnas = {}
    for tabla, cuerpo in re.findall(r"CREATE TABLE IF NOT EXISTS (\w+) \((.*?)\n\);", sql, re.S):
        for columna, largo in re.findall(r"^\s+(\w+)\s+VARCHAR\((\d+)\)", cuerpo, re.M):
            columnas[(tabla, columna)] = int(largo)
    return columnas


def test_cada_limite_de_entrada_es_el_largo_exacto_de_su_columna():
    varchar = _varchar_de_schema()
    for clave, limite in LIMITES_DE_ENTRADA.items():
        assert varchar[clave] == limite, f"{clave[0]}.{clave[1]}: BD={varchar[clave]} código={limite}"


def test_toda_columna_varchar_tiene_un_limite_en_el_codigo_o_es_interna():
    """Si alguien agrega un VARCHAR nuevo a schema.sql, esta prueba obliga a definir su límite."""
    sin_limite = set(_varchar_de_schema()) - set(LIMITES_DE_ENTRADA) - VARCHAR_INTERNOS
    assert not sin_limite, f"Columnas VARCHAR sin límite en utils/limites.py: {sorted(sin_limite)}"


def test_los_valores_internos_caben_en_sus_columnas():
    varchar = _varchar_de_schema()
    assert all(len(r.value) <= varchar[("usuarios", "rol")] for r in Rol)
    assert all(len(e.value) <= varchar[("reservas", "estado")] for e in EstadoReserva)
    assert all(len(e.value) <= varchar[("tokens", "estado")] for e in EstadoToken)
    assert 60 <= varchar[("usuarios", "password_hash")]  # un hash bcrypt mide 60 caracteres


def test_los_limites_numericos_caben_en_la_base():
    sql = (CARPETA_SQL / "schema.sql").read_text(encoding="utf-8")
    entero_maximo = 2**31 - 1
    assert limites.MAX_VERSION <= entero_maximo
    assert limites.CAPACIDAD_MAXIMA <= entero_maximo
    assert limites.ASIENTOS_POR_RESERVA <= entero_maximo
    assert limites.MAX_ID <= 2**63 - 1  # los id son BIGINT
    assert "precio                NUMERIC(10,2)" in sql
    assert limites.PRECIO_MAXIMO < 10 ** (10 - 2)  # NUMERIC(10,2) admite hasta 99 999 999,99


# ---------------------------------------------------------------- contra la BD desplegada

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")


@pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omite la comparación con la BD real.")
def test_la_base_real_tiene_los_mismos_largos_que_el_codigo():
    db = Database(URL)
    try:
        with db.transaccion() as cur:
            cur.execute(
                "SELECT table_name, column_name, character_maximum_length, numeric_precision, numeric_scale "
                "FROM information_schema.columns WHERE table_schema = 'public'"
            )
            columnas = {(f["table_name"], f["column_name"]): f for f in cur.fetchall()}
    finally:
        db.cerrar()

    for clave, limite in LIMITES_DE_ENTRADA.items():
        assert columnas[clave]["character_maximum_length"] == limite, f"{clave} en la BD real"
    precio = columnas[("vuelos", "precio")]
    assert (precio["numeric_precision"], precio["numeric_scale"]) == (10, 2)
