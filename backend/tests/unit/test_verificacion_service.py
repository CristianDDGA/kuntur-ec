import re

import pytest

from services.verificacion_service import MAX_INTENTOS, VerificacionService
from tests.factories import un_usuario
from tests.fakes import BaseDatosFalsa
from utils.correo import EnviadorLocal
from utils.excepciones import ServiceUnavailableError, ValidationError

CLAVE = "clave-de-pruebas-suficientemente-larga-32b"
USUARIO = un_usuario(id=7, nombre="Ana Torres", correo="ana@correo.com")


def _servicio(filas=None, enviador=None, error=None):
    db = BaseDatosFalsa(filas=filas, error=error)
    enviador = enviador or EnviadorLocal()
    return VerificacionService(db, enviador, CLAVE), db, enviador


def _fila_codigo(servicio, codigo="123456", intentos=0, vigente=True, verificado=False, hash_=...):
    return {
        "id": 7,
        "correo_verificado": verificado,
        "codigo_hash": servicio._huella(7, codigo) if hash_ is ... else hash_,
        "intentos": intentos,
        "vigente": vigente,
    }


# ---------------------------------------------------------------- enviar


def test_el_codigo_se_envia_por_correo_y_en_la_base_solo_queda_su_huella():
    servicio, db, enviador = _servicio()
    servicio.enviar_codigo(USUARIO)

    (destino, asunto, texto), = enviador.enviados
    codigo = re.search(r"\b(\d{6})\b", texto).group(1)
    assert destino == "ana@correo.com" and "Kuntur EC" in asunto and "10 minutos" in texto

    sql, params = db.cursor.consultas[0]
    assert "INSERT INTO codigos_verificacion" in sql and "ON CONFLICT (usuario_id) DO UPDATE" in sql  # uno vigente por cuenta
    assert params[0] == 7
    assert params[1] == servicio._huella(7, codigo) and codigo not in params[1]  # nunca el código en claro


def test_cada_envio_genera_un_codigo_distinto_de_6_digitos():
    servicio, _, enviador = _servicio()
    for _ in range(20):
        servicio.enviar_codigo(USUARIO)
    codigos = {re.search(r"\b(\d{6})\b", t).group(1) for _, _, t in enviador.enviados}
    assert len(codigos) > 15


def test_la_huella_depende_de_la_cuenta_y_de_la_clave():
    a, _, _ = _servicio()
    b = VerificacionService(BaseDatosFalsa(), EnviadorLocal(), "otra-clave-distinta-de-pruebas-xxxxxxxx")
    assert a._huella(7, "123456") != a._huella(8, "123456")  # el mismo código en otra cuenta no sirve
    assert a._huella(7, "123456") != b._huella(7, "123456")


def test_si_el_correo_falla_el_registro_no_se_cae():
    class Roto:
        def enviar(self, *a, **k):
            raise ServiceUnavailableError("sin correo")

    servicio, _, _ = _servicio(enviador=Roto())
    assert servicio.enviar_tras_registro(USUARIO) is False
    with pytest.raises(ServiceUnavailableError):  # pero pedir otro código sí avisa del problema
        servicio.enviar_codigo(USUARIO)


# ---------------------------------------------------------------- verificar


def test_un_codigo_correcto_verifica_la_cuenta_y_borra_el_codigo():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio)]
    assert servicio.verificar({"correo": " Ana@Correo.com ", "codigo": " 123456 "}) == {"correo": "ana@correo.com"}
    sqls = [s for s, _ in db.cursor.consultas]
    assert any("UPDATE usuarios SET correo_verificado = TRUE" in s for s in sqls)
    assert any("DELETE FROM codigos_verificacion" in s for s in sqls)


def test_un_codigo_incorrecto_cuenta_el_intento_y_dice_cuantos_quedan():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio, intentos=1)]
    with pytest.raises(ValidationError, match="Le quedan 3 intentos"):
        servicio.verificar({"correo": "ana@correo.com", "codigo": "000000"})
    assert any("intentos = intentos + 1" in s for s, _ in db.cursor.consultas)
    assert not any("correo_verificado = TRUE" in s for s, _ in db.cursor.consultas)


def test_el_ultimo_intento_fallido_pide_un_codigo_nuevo():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio, intentos=MAX_INTENTOS - 1)]
    with pytest.raises(ValidationError, match="se agotaron los intentos"):
        servicio.verificar({"correo": "ana@correo.com", "codigo": "000000"})


@pytest.mark.parametrize(
    "fila",
    [
        None,                                              # la cuenta no existe
        {"id": 7, "correo_verificado": True, "codigo_hash": "x", "intentos": 0, "vigente": True},      # ya verificada
        {"id": 7, "correo_verificado": False, "codigo_hash": None, "intentos": None, "vigente": None},  # sin código
        {"id": 7, "correo_verificado": False, "codigo_hash": "x", "intentos": 0, "vigente": False},    # vencido
        {"id": 7, "correo_verificado": False, "codigo_hash": "x", "intentos": MAX_INTENTOS, "vigente": True},  # sin intentos
    ],
    ids=["no-existe", "ya-verificada", "sin-codigo", "vencido", "sin-intentos"],
)
def test_todo_lo_que_no_sirve_responde_lo_mismo_sin_revelar_nada(fila):
    servicio, db, _ = _servicio(filas=[fila])
    with pytest.raises(ValidationError, match="no es correcto o ya venció"):
        servicio.verificar({"correo": "ana@correo.com", "codigo": "123456"})
    assert not any("correo_verificado = TRUE" in s for s, _ in db.cursor.consultas)


@pytest.mark.parametrize("codigo", [None, "", "12345", "1234567", "abcdef", "12 456", 123456, "１２３４５６"])
def test_el_codigo_debe_tener_exactamente_6_digitos(codigo):
    servicio, db, _ = _servicio()
    with pytest.raises(ValidationError, match="6 dígitos"):
        servicio.verificar({"correo": "ana@correo.com", "codigo": codigo})
    assert db.cursor.consultas == []  # ni siquiera se consulta la base


def test_el_correo_debe_ser_valido():
    with pytest.raises(ValidationError, match="correo"):
        _servicio()[0].verificar({"correo": "no-es-correo", "codigo": "123456"})


# ---------------------------------------------------------------- reenviar


def _fila_reenvio(verificado=False, puede=True):
    return {"id": 7, "nombre": "Ana Torres", "correo": "ana@correo.com", "correo_verificado": verificado, "puede": puede}


def test_reenviar_a_una_cuenta_pendiente_manda_un_codigo_nuevo():
    servicio, _, enviador = _servicio(filas=[_fila_reenvio()])
    assert "le enviamos un código nuevo" in servicio.reenviar({"correo": "ana@correo.com"})["mensaje"]
    assert len(enviador.enviados) == 1


@pytest.mark.parametrize(
    "fila",
    [None, _fila_reenvio(verificado=True), _fila_reenvio(puede=False)],
    ids=["no-existe", "ya-verificada", "muy-pronto"],
)
def test_reenviar_responde_igual_pero_no_envia_si_no_corresponde(fila):
    servicio, _, enviador = _servicio(filas=[fila])
    respuesta = servicio.reenviar({"correo": "ana@correo.com"})
    assert respuesta["mensaje"].startswith("Si la cuenta existe")  # no revela si existe
    assert enviador.enviados == []
