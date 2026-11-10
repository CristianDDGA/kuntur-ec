from datetime import datetime, timedelta, timezone

import pytest

from utils.excepciones import UnauthorizedError
from utils.seguridad import EmisorTokens, huella_token

emisor = EmisorTokens("clave-de-pruebas-suficientemente-larga-32b", minutos_validez=60)


def test_emitir_y_leer_un_token():
    emitido = emisor.emitir(7, "cliente")
    datos = emisor.leer(emitido.valor)
    assert (datos.usuario_id, datos.rol) == (7, "cliente")
    assert datos.expiracion == emitido.expiracion.replace(microsecond=0)


def test_dos_logins_del_mismo_usuario_dan_tokens_distintos():
    assert emisor.emitir(7, "cliente").valor != emisor.emitir(7, "cliente").valor


def test_token_expirado():
    viejo = emisor.emitir(7, "cliente", ahora=datetime.now(timezone.utc) - timedelta(hours=2))
    with pytest.raises(UnauthorizedError, match="expiró"):
        emisor.leer(viejo.valor)


@pytest.mark.parametrize(
    "valor",
    ["no-es-un-jwt", EmisorTokens("otra-clave-distinta-tambien-de-32-bytes", 60).emitir(7, "admin").valor],
    ids=["texto", "otra-clave"],
)
def test_token_alterado_o_firmado_con_otra_clave(valor):
    with pytest.raises(UnauthorizedError, match="no es válido"):
        emisor.leer(valor)


def test_la_huella_no_contiene_el_token():
    valor = emisor.emitir(7, "cliente").valor
    assert huella_token(valor) != valor and len(huella_token(valor)) == 64
