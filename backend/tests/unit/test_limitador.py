import pytest

from utils.excepciones import TooManyRequestsError
from utils.limitador import LimitadorIntentos


class Reloj:
    def __init__(self):
        self.ahora = 1000.0

    def __call__(self):
        return self.ahora


@pytest.fixture
def reloj():
    return Reloj()


@pytest.fixture
def limitador(reloj):
    return LimitadorIntentos(maximo=3, ventana_segundos=60, reloj=reloj)


def _fallar(limitador, clave, veces):
    for _ in range(veces):
        limitador.verificar(clave)
        limitador.registrar_fallo(clave)


def test_bloquea_al_superar_el_maximo_con_tiempo_de_espera(limitador, reloj):
    _fallar(limitador, "ip|ana", 3)
    reloj.ahora += 20
    with pytest.raises(TooManyRequestsError) as error:
        limitador.verificar("ip|ana")
    assert error.value.detalles["reintentar_en_segundos"] == 40


def test_los_fallos_de_una_clave_no_afectan_a_otra(limitador):
    _fallar(limitador, "ip|ana", 3)
    limitador.verificar("ip|beto")  # no lanza
    limitador.verificar("otra-ip|ana")  # no lanza


def test_el_bloqueo_termina_al_vencer_la_ventana(limitador, reloj):
    _fallar(limitador, "ip|ana", 3)
    reloj.ahora += 60
    limitador.verificar("ip|ana")  # no lanza


def test_un_login_correcto_reinicia_el_conteo(limitador):
    _fallar(limitador, "ip|ana", 2)
    limitador.limpiar("ip|ana")
    _fallar(limitador, "ip|ana", 2)
    limitador.verificar("ip|ana")  # 2 < 3: no lanza


def test_la_memoria_no_crece_sin_limite(reloj):
    limitador = LimitadorIntentos(maximo=3, ventana_segundos=60, reloj=reloj, capacidad=50)
    for i in range(500):
        limitador.registrar_fallo(f"ip|{i}")
    assert len(limitador._fallos) <= 50
