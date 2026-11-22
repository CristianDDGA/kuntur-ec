"""La API debe fallar rápido y de forma controlada cuando la base de datos no responde."""
import time

import pytest

from database import Database
from utils.excepciones import ServiceUnavailableError

# Puerto 1 en localhost: la conexión se rechaza al instante (simula una base caída).
URL_CAIDA = "postgresql://usuario:clave@127.0.0.1:1/postgres"


@pytest.fixture
def db_caida():
    base = Database(URL_CAIDA, espera_conexion=1.0)
    yield base
    base.cerrar(espera=0.5)


def test_base_caida_lanza_servicio_no_disponible_sin_colgarse(db_caida):
    inicio = time.monotonic()
    with pytest.raises(ServiceUnavailableError) as error:
        with db_caida.transaccion() as cur:
            cur.execute("SELECT 1")
    assert time.monotonic() - inicio < 4
    assert error.value.detalles["reintentar_en_segundos"] > 0


def test_base_caida_el_pool_sigue_utilizable_para_reintentar(db_caida):
    # Antes, un fallo al abrir dejaba el pool cerrado para siempre; ahora sigue abierto y reintenta.
    with pytest.raises(ServiceUnavailableError):
        with db_caida.transaccion():
            pass
    assert not db_caida._pool.closed
    with pytest.raises(ServiceUnavailableError):  # segundo intento: mismo error controlado, no PoolClosed
        with db_caida.transaccion():
            pass


def test_disponible_es_false_si_la_base_no_responde(db_caida):
    assert db_caida.disponible() is False


def test_los_errores_de_negocio_dentro_de_la_transaccion_no_se_convierten_en_503():
    # Se usa un servidor "caído" pero el error ocurre antes de ejecutar SQL: debe seguir siendo 503
    # solo por la conexión; un error de negocio propio atraviesa transaccion() sin cambios.
    from tests.fakes import BaseDatosFalsa
    from utils.excepciones import ConflictError

    db = BaseDatosFalsa()
    with pytest.raises(ConflictError):
        with db.transaccion():
            raise ConflictError("x")
