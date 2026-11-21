import pytest

from utils.excepciones import ValidationError
from utils.importacion_csv import leer_aviones


def _csv(*lineas: str, sep: str = ";") -> bytes:
    return "\n".join(l.replace(";", sep) for l in lineas).encode("utf-8")


def test_lee_aviones_validos_con_punto_y_coma_o_coma():
    for sep in (";", ","):
        r = leer_aviones(_csv("matricula;modelo;filas", "hc-abc;Airbus A320;30", "HC-XYZ;ATR 72;18", sep=sep))
        assert r.errores == [] and r.total_filas == 2
        assert [(f.matricula, f.modelo, f.filas) for f in r.validas] == [
            ("HC-ABC", "Airbus A320", 30),
            ("HC-XYZ", "ATR 72", 18),
        ]


def test_acepta_bom_acentos_en_el_encabezado_y_lineas_en_blanco():
    contenido = "﻿Matrícula;Modelo;Filas\n\nHC-ABC;A320;30\n".encode("utf-8")
    r = leer_aviones(contenido)
    assert len(r.validas) == 1 and r.errores == []


def test_reporta_cada_fila_invalida_con_su_linea():
    r = leer_aviones(_csv(
        "matricula;modelo;filas",
        "HC-ABC;Airbus A320;30",  # línea 2: bien
        "x;Modelo;10",            # línea 3: matrícula corta
        "HC-DEF;;10",             # línea 4: sin modelo
        "HC-GHI;ATR;51",          # línea 5: filas de más
        "HC-JKL;ATR;diez",        # línea 6: filas no numéricas
        "HC-MNO;ATR",             # línea 7: faltan columnas
        "HC-ABC;Otro;5",          # línea 8: repetida
    ))
    assert len(r.validas) == 1
    assert sorted({e["linea"] for e in r.errores}) == [3, 4, 5, 6, 7, 8]
    assert "repetida" in [e["mensaje"] for e in r.errores if e["linea"] == 8][0]


@pytest.mark.parametrize(
    "contenido, mensaje",
    [
        (b"", "vacío"),
        (b"   \n", "vacío"),
        (b"solo una columna\nx", "encabezado"),
        (_csv("matricula;modelo;capacidad", "HC-ABC;A320;30"), "encabezado"),
        (b"\xff\xfe\x00bad;bytes", "UTF-8"),
    ],
)
def test_archivos_que_no_sirven_se_rechazan_enteros(contenido, mensaje):
    with pytest.raises(ValidationError, match=mensaje):
        leer_aviones(contenido)


def test_rechaza_archivos_demasiado_grandes_o_con_demasiadas_filas():
    with pytest.raises(ValidationError, match="KB"):
        leer_aviones(b"a" * (1024 * 1024 + 1))
    filas = ["matricula;modelo;filas"] + [f"HC-{i:04d};A320;10" for i in range(501)]
    with pytest.raises(ValidationError, match="500"):
        leer_aviones(_csv(*filas))
