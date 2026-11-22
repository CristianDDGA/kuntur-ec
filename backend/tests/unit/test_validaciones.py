from datetime import time
from decimal import Decimal

import pytest

from utils.excepciones import ValidationError
from utils.validaciones import (
    MAX_ID,
    correo,
    entero,
    es_correo,
    fecha_iso,
    hora_hhmm,
    identificador,
    nombre_propio,
    precio,
    revisar_json,
    revisar_texto,
    texto_obligatorio,
)

# ---------------------------------------------------------------- nombres y ciudades


@pytest.mark.parametrize(
    "nombre",
    ["Ana Torres", "José Ñandú", "O'Brien-Pérez", "María de los Ángeles", "Dr. Juan", "Zoë", "李小龙", "émile"],
)
def test_nombres_validos(nombre):
    assert nombre_propio({"n": nombre}, "n", 100)


@pytest.mark.parametrize(
    "nombre",
    [
        "Ana 😀", "😀😀😀", "<script>alert(1)</script>", "Robert'); DROP TABLE usuarios;--",
        "Ana123", "Ana #$%", "Ana\nTorres", "Ana\tTorres", "Ana\x00Torres", "Ana‍Torres",
        "A", "- - -", "Ana@Torres", "Ana_Torres", "Ana/Torres", "Ana‮Torres",
    ],
)
def test_nombres_invalidos(nombre):
    with pytest.raises(ValidationError):
        nombre_propio({"n": nombre}, "n", 100)


def test_el_nombre_se_normaliza_espacios_y_tildes():
    assert nombre_propio({"n": "  Ana   Torres "}, "n", 100) == "Ana Torres"
    assert nombre_propio({"n": "José"}, "n", 100) == "José"  # NFC


def test_largo_maximo():
    with pytest.raises(ValidationError, match="100 caracteres"):
        nombre_propio({"n": "A" * 101}, "n", 100)


@pytest.mark.parametrize("valor", [None, 5, [], {}, True, "", "   "])
def test_texto_obligatorio_rechaza_lo_que_no_es_texto(valor):
    with pytest.raises(ValidationError, match="es obligatorio"):
        texto_obligatorio({"x": valor}, "x", 10)


# ---------------------------------------------------------------- caracteres de control


@pytest.mark.parametrize("texto", ["a\x00b", "a\nb", "a\tb", "a\x1bb", "a\x7fb", "a\ud800b"])
def test_revisar_texto_rechaza_control(texto):
    with pytest.raises(ValidationError, match="caracteres no permitidos"):
        revisar_texto(texto, "campo")


def test_revisar_texto_acepta_emojis_y_tildes():
    revisar_texto("Clave 😀 ñandú ü", "campo")  # en contraseñas son válidos


def test_revisar_json_revisa_claves_y_anidados():
    with pytest.raises(ValidationError):
        revisar_json({"a": {"b": ["ok", "mal\x00"]}})
    with pytest.raises(ValidationError):
        revisar_json({"cl\x00ave": 1})


@pytest.mark.parametrize("valor", [float("nan"), float("inf"), float("-inf")])
def test_revisar_json_rechaza_numeros_no_finitos(valor):
    with pytest.raises(ValidationError, match="finito"):
        revisar_json({"precio": valor})


def test_revisar_json_rechaza_estructuras_profundas():
    profundo = {"a": {"b": {"c": {"d": {"e": {"f": 1}}}}}}
    with pytest.raises(ValidationError, match="profunda"):
        revisar_json(profundo)


# ---------------------------------------------------------------- correo


@pytest.mark.parametrize("valor", ["ana@correo.com", "a.b+c@sub.dominio.ec", "A_B-1@x.co"])
def test_correos_validos(valor):
    assert es_correo(valor)


@pytest.mark.parametrize(
    "valor",
    ["ana😀@correo.com", "ana torres@correo.com", "' OR 1=1 --@x.com", "<script>@x.com", "ana@", "a@b@c.com",
     "ana@correo", "@correo.com", ".ana@correo.com", "ana.@correo.com", "ana..t@correo.com", "ana@-.com",
     "ñandú@correo.com", "a" * 65 + "@x.com", "ana@correo.c"],
)
def test_correos_invalidos(valor):
    assert not es_correo(valor)


def test_correo_se_normaliza_a_minusculas_y_valida_largo():
    assert correo({"correo": "  ANA@Correo.COM "}) == "ana@correo.com"
    with pytest.raises(ValidationError, match="150"):
        correo({"correo": "a" * 150 + "@x.com"})


# ---------------------------------------------------------------- números


@pytest.mark.parametrize("valor", [-1, 0, 11, 1.5, "3", None, True, 10**30, [1]])
def test_entero_fuera_de_rango_o_de_otro_tipo(valor):
    with pytest.raises(ValidationError, match="entero entre 1 y 10"):
        entero({"c": valor}, "c", 1, 10)


def test_entero_valido():
    assert entero({"c": 10}, "c", 1, 10) == 10


@pytest.mark.parametrize("valor", [0, -1, MAX_ID + 1, 2**63, 1.0, "1", True, None])
def test_identificador_invalido(valor):
    with pytest.raises(ValidationError, match="identificador"):
        identificador({"id": valor}, "id")


def test_identificador_valido():
    assert identificador({"id": MAX_ID}, "id") == MAX_ID


@pytest.mark.parametrize(("valor", "esperado"), [(75.5, "75.5"), (10, "10"), ("99.99", "99.99"), (10000, "10000")])
def test_precio_valido(valor, esperado):
    assert precio({"precio": valor}) == Decimal(esperado)


@pytest.mark.parametrize(
    ("valor", "mensaje"),
    [
        (-50, "mayor a 0"), (0, "mayor a 0"), ("NaN", "numérico"), ("Infinity", "numérico"),
        ("gratis", "numérico"), (True, "numérico"), (None, "numérico"), ([1], "numérico"),
        (10.555, "2 decimales"), ("0.001", "2 decimales"),
        (1e12, "no puede superar"), (10000.01, "no puede superar"), ("1E+400", "no puede superar"),
    ],
)
def test_precio_invalido(valor, mensaje):
    with pytest.raises(ValidationError, match=mensaje):
        precio({"precio": valor})


# ---------------------------------------------------------------- fechas y horas


@pytest.mark.parametrize("valor", ["2026-12-01", " 2026-12-01 "])
def test_fecha_valida(valor):
    assert fecha_iso(valor).isoformat() == "2026-12-01"


@pytest.mark.parametrize(
    "valor",
    ["01/12/2026", "2026-13-01", "2026-02-30", "20261201", "2026-W01-1", "2026-1-1", "٢٠٢٦-١٢-٠١", "", None, 20261201, "2026-12-\n01"],
)
def test_fecha_invalida(valor):
    with pytest.raises(ValidationError, match="AAAA-MM-DD"):
        fecha_iso(valor)


@pytest.mark.parametrize(("valor", "esperada"), [("08:00", time(8, 0)), ("23:59", time(23, 59)), (" 07:05 ", time(7, 5))])
def test_hora_valida(valor, esperada):
    assert hora_hhmm(valor, "hora") == esperada


@pytest.mark.parametrize("valor", ["25:00", "8:00", "08:60", "ocho", "08:00:00", "", None, 800])
def test_hora_invalida(valor):
    with pytest.raises(ValidationError, match="HH:MM"):
        hora_hhmm(valor, "hora")
