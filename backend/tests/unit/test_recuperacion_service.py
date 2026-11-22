import re

import pytest

from services.recuperacion_service import MAX_INTENTOS, RecuperacionService
from services.verificacion_service import VerificacionService
from tests.fakes import BaseDatosFalsa, CifradorFalso
from utils.correo import EnviadorLocal
from utils.excepciones import ServiceUnavailableError, ValidationError

CLAVE = "clave-de-pruebas-suficientemente-larga-32b"
NUEVA = "NuevaClave2026"


def _servicio(filas=None, enviador=None, error=None):
    db = BaseDatosFalsa(filas=filas, error=error)
    enviador = enviador or EnviadorLocal()
    return RecuperacionService(db, enviador, CLAVE, CifradorFalso()), db, enviador


def _fila_cuenta(puede=True):
    return {"id": 7, "nombre": "Ana Torres", "correo": "ana@correo.com", "puede": puede}


def _fila_codigo(servicio, codigo="123456", intentos=0, vigente=True, hash_=...):
    return {
        "id": 7,
        "codigo_hash": servicio._huella(7, codigo) if hash_ is ... else hash_,
        "intentos": intentos,
        "vigente": vigente,
    }


def _restablecer(servicio, codigo="123456", password=NUEVA, correo="ana@correo.com"):
    return servicio.restablecer({"correo": correo, "codigo": codigo, "password": password})


# ---------------------------------------------------------------- solicitar


def test_pedir_el_codigo_envia_un_correo_y_en_la_base_solo_queda_su_huella():
    servicio, db, enviador = _servicio(filas=[_fila_cuenta()])
    r = servicio.solicitar({"correo": " Ana@Correo.com "})

    assert r["mensaje"].startswith("Si el correo está registrado")
    (destino, asunto, texto), = enviador.enviados
    codigo = re.search(r"\b(\d{6})\b", texto).group(1)
    assert destino == "ana@correo.com" and "Restablezca" in asunto and "10 minutos" in texto
    assert "su contraseña no cambiará" in texto  # quien no lo pidió sabe que puede ignorarlo

    sql, params = db.cursor.consultas[1]
    assert "INSERT INTO codigos_recuperacion" in sql and "ON CONFLICT (usuario_id) DO UPDATE" in sql
    assert params[0] == 7 and params[1] == servicio._huella(7, codigo)
    assert codigo not in params[1]  # nunca el código en claro


def test_la_huella_de_recuperacion_no_coincide_con_la_de_verificacion():
    servicio, _, _ = _servicio()
    verificacion = VerificacionService(BaseDatosFalsa(), EnviadorLocal(), CLAVE)
    assert servicio._huella(7, "123456") != verificacion._huella(7, "123456")
    assert servicio._huella(7, "123456") != servicio._huella(8, "123456")


def test_si_la_cuenta_no_existe_responde_lo_mismo_y_no_envia_nada():
    servicio, db, enviador = _servicio(filas=[None])
    r = servicio.solicitar({"correo": "nadie@correo.com"})
    assert r["mensaje"].startswith("Si el correo está registrado")
    assert enviador.enviados == [] and len(db.cursor.consultas) == 1


def test_antes_de_60_segundos_no_se_envia_otro():
    servicio, _, enviador = _servicio(filas=[_fila_cuenta(puede=False)])
    assert servicio.solicitar({"correo": "ana@correo.com"})["mensaje"].startswith("Si el correo está registrado")
    assert enviador.enviados == []


def test_si_el_correo_falla_se_responde_igual_sin_revelar_que_la_cuenta_existe():
    class Roto:
        def enviar(self, *a, **k):
            raise ServiceUnavailableError("sin correo")

    servicio, _, _ = _servicio(filas=[_fila_cuenta()], enviador=Roto())
    assert servicio.solicitar({"correo": "ana@correo.com"})["mensaje"].startswith("Si el correo está registrado")


@pytest.mark.parametrize("datos", [{}, {"correo": ""}, {"correo": "no-es-correo"}, {"correo": 5}, {"correo": "a b@x.com"}])
def test_el_correo_debe_ser_valido(datos):
    servicio, db, _ = _servicio()
    with pytest.raises(ValidationError):
        servicio.solicitar(datos)
    assert db.cursor.consultas == []


# ---------------------------------------------------------------- restablecer


def test_un_codigo_correcto_cambia_la_clave_borra_los_codigos_y_cierra_las_sesiones():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio)]
    assert _restablecer(servicio)["mensaje"].startswith("Contraseña actualizada")

    consultas = db.cursor.consultas
    sqls = [s for s, _ in consultas]
    sql_update, params = next((s, p) for s, p in consultas if s.startswith("UPDATE usuarios SET password_hash"))
    assert "correo_verificado = TRUE" in sql_update  # el código prueba que controla el correo
    assert params == (f"hash::{NUEVA}", 7)  # se guarda cifrada, nunca en claro
    assert any("DELETE FROM codigos_recuperacion" in s for s in sqls)
    assert any("DELETE FROM codigos_verificacion" in s for s in sqls)
    assert any("UPDATE tokens SET estado = 'revocado'" in s for s in sqls)  # cierra las sesiones abiertas


def test_un_codigo_incorrecto_cuenta_el_intento_y_dice_cuantos_quedan():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio, intentos=1)]
    with pytest.raises(ValidationError, match="Le quedan 3 intentos"):
        _restablecer(servicio, codigo="000000")
    sqls = [s for s, _ in db.cursor.consultas]
    assert any("intentos = intentos + 1" in s for s in sqls)
    assert not any("password_hash" in s for s in sqls)  # la clave no cambió


def test_el_ultimo_intento_fallido_pide_un_codigo_nuevo():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio, intentos=MAX_INTENTOS - 1)]
    with pytest.raises(ValidationError, match="se agotaron los intentos"):
        _restablecer(servicio, codigo="000000")


@pytest.mark.parametrize(
    "fila",
    [
        None,                                                       # la cuenta no existe
        {"id": 7, "codigo_hash": None, "intentos": None, "vigente": None},          # nunca pidió código
        {"id": 7, "codigo_hash": "x", "intentos": 0, "vigente": False},             # vencido
        {"id": 7, "codigo_hash": "x", "intentos": MAX_INTENTOS, "vigente": True},   # sin intentos
    ],
    ids=["no-existe", "sin-codigo", "vencido", "sin-intentos"],
)
def test_todo_lo_que_no_sirve_responde_lo_mismo_sin_revelar_nada(fila):
    servicio, db, _ = _servicio(filas=[fila])
    with pytest.raises(ValidationError, match="no es correcto o ya venció"):
        _restablecer(servicio)
    assert not any("password_hash" in s for s, _ in db.cursor.consultas)


def test_el_codigo_de_otra_cuenta_no_sirve():
    servicio, db, _ = _servicio()
    db.cursor._filas = [_fila_codigo(servicio, hash_=servicio._huella(8, "123456"))]  # huella de la cuenta 8
    with pytest.raises(ValidationError, match="no es correcto"):
        _restablecer(servicio)


@pytest.mark.parametrize("codigo", [None, "", "12345", "1234567", "abcdef", "12 456", 123456, "１２３４５６"])
def test_el_codigo_debe_tener_exactamente_6_digitos(codigo):
    servicio, db, _ = _servicio()
    with pytest.raises(ValidationError, match="6 dígitos"):
        _restablecer(servicio, codigo=codigo)
    assert db.cursor.consultas == []


@pytest.mark.parametrize(
    "password, mensaje",
    [
        ("corta1", "al menos 8"),
        ("sololetrasaqui", "letras y números"),
        ("123456789012", "letras y números"),
        ("a1" * 40, "demasiado larga"),
        ("", "obligatorio"),
        (None, "obligatorio"),
    ],
)
def test_una_clave_que_no_cumple_las_reglas_se_rechaza_sin_gastar_un_intento(password, mensaje):
    servicio, db, _ = _servicio()
    with pytest.raises(ValidationError, match=mensaje):
        _restablecer(servicio, password=password)
    assert db.cursor.consultas == []  # ni siquiera se consulta la base: el código no pierde un intento


def test_el_correo_debe_ser_valido():
    with pytest.raises(ValidationError, match="correo"):
        _restablecer(_servicio()[0], correo="no-es-correo")
