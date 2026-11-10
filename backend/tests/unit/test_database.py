import re

import pytest

from config import ConfigurationError
from database import CARPETA_SQL, SCRIPTS_INICIALES, Database

TABLAS = ("usuarios", "vuelos", "tarifas_iva", "reservas", "tokens")


def test_sin_url_lanza_error_de_configuracion():
    with pytest.raises(ConfigurationError):
        Database("")


def test_el_pool_no_se_abre_al_crear_la_instancia():
    # La app debe poder arrancar aunque la BD no responda todavía.
    db = Database("postgresql://usuario:clave@host-inexistente.invalid:5432/postgres")
    assert db._pool.closed


def test_los_scripts_iniciales_existen():
    for nombre in SCRIPTS_INICIALES:
        assert (CARPETA_SQL / nombre).is_file()


@pytest.mark.parametrize("tabla", TABLAS)
def test_el_esquema_crea_cada_tabla_con_rls(tabla):
    sql = (CARPETA_SQL / "schema.sql").read_text(encoding="utf-8")
    assert re.search(rf"CREATE TABLE IF NOT EXISTS {tabla} \(", sql)
    assert f"ALTER TABLE {tabla}" in sql and "ENABLE ROW LEVEL SECURITY" in sql


def test_el_seed_tiene_una_sola_tarifa_iva_abierta():
    seed = (CARPETA_SQL / "seed.sql").read_text(encoding="utf-8")
    assert seed.count("NULL)") == 1
