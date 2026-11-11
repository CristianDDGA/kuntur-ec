from datetime import date
from decimal import Decimal

import pytest

from services.iva_service import IvaService
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ConflictError, ValidationError

HOY = date(2026, 11, 10)


def _fila(id=1, porcentaje="15.00", desde=date(2024, 4, 1), hasta=None):
    return {"id": id, "porcentaje": Decimal(porcentaje), "vigente_desde": desde, "vigente_hasta": hasta}


def _servicio(db):
    return IvaService(db, hoy=lambda: HOY)


# ---------------------------------------------------------------- consultar


def test_consultar_marca_vigente_programada_y_anterior():
    db = BaseDatosFalsa(filas=[
        _fila(3, "13.00", date(2027, 1, 1)),                          # programada
        _fila(2, "15.00", date(2024, 4, 1), date(2027, 1, 1)),        # vigente hoy
        _fila(1, "12.00", date(2000, 1, 1), date(2024, 4, 1)),        # anterior
    ])
    r = _servicio(db).consultar()
    assert [t["estado"] for t in r["tarifas"]] == ["programada", "vigente", "anterior"]
    assert r["vigente"]["id"] == 2


def test_consultar_sin_tarifas():
    assert _servicio(BaseDatosFalsa()).consultar() == {"vigente": None, "tarifas": []}


# ---------------------------------------------------------------- cambiar


def _cambiar(db, **datos):
    return _servicio(db).cambiar({"porcentaje": 13, "vigente_desde": "2027-01-01"} | datos)


def test_cambiar_cierra_la_abierta_e_inserta_la_nueva_en_una_transaccion():
    db = BaseDatosFalsa(filas=[{"ultima": date(2024, 4, 1)}, _fila(4, "13.00", date(2027, 1, 1))])
    tarifa = _cambiar(db)
    sqls = [c[0] for c in db.cursor.consultas]
    assert sqls[0].startswith("LOCK TABLE tarifas_iva")
    assert "UPDATE tarifas_iva SET vigente_hasta" in sqls[2]
    assert db.cursor.consultas[2][1] == (date(2027, 1, 1),)
    assert "INSERT INTO tarifas_iva" in sqls[3]
    assert db.cursor.consultas[3][1] == (Decimal("13"), date(2027, 1, 1))
    assert tarifa["estado"] == "programada" and tarifa["porcentaje"] == Decimal("13.00")


def test_cambiar_desde_hoy_queda_vigente():
    db = BaseDatosFalsa(filas=[{"ultima": date(2024, 4, 1)}, _fila(4, "13.00", HOY)])
    assert _cambiar(db, vigente_desde="2026-11-10")["estado"] == "vigente"


def test_primera_tarifa_sin_historial():
    db = BaseDatosFalsa(filas=[{"ultima": None}, _fila(1, "15.00", HOY)])
    assert _cambiar(db, porcentaje=15, vigente_desde="2026-11-10")["id"] == 1


def test_no_se_puede_empezar_en_el_pasado():
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match="pasado"):
        _cambiar(db, vigente_desde="2026-11-09")
    assert db.cursor.consultas == []


def test_no_se_puede_programar_a_mas_de_dos_anios():
    with pytest.raises(ValidationError, match="2 años"):
        _cambiar(BaseDatosFalsa(), vigente_desde="2028-11-11")


def test_no_se_puede_empezar_antes_o_el_mismo_dia_que_la_ultima_tarifa():
    for desde in ("2027-01-01", "2026-12-15"):
        db = BaseDatosFalsa(filas=[{"ultima": date(2027, 1, 1)}])
        with pytest.raises(ConflictError, match="01/01/2027"):
            _cambiar(db, vigente_desde=desde)
        assert len(db.cursor.consultas) == 2  # se detuvo antes del UPDATE/INSERT


@pytest.mark.parametrize("porcentaje", [
    -1, 100.01, 101, 12.345, "abc", "", None, True, [], {}, "NaN", "Infinity", "1e2000", "12,5", " ",
])
def test_porcentaje_invalido_no_toca_la_bd(porcentaje):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError):
        _cambiar(db, porcentaje=porcentaje)
    assert db.cursor.consultas == []


@pytest.mark.parametrize("porcentaje", [0, 12, 15.5, "15.50", 100, "0.01"])
def test_porcentajes_validos(porcentaje):
    db = BaseDatosFalsa(filas=[{"ultima": None}, _fila(1, "15.00", date(2027, 1, 1))])
    _cambiar(db, porcentaje=porcentaje)


@pytest.mark.parametrize("fecha", [None, "", "01/01/2027", "20270101", "2027-13-01", "2027-02-30", 20270101, "2027-W01-1"])
def test_fecha_invalida_no_toca_la_bd(fecha):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError):
        _cambiar(db, vigente_desde=fecha)
    assert db.cursor.consultas == []
