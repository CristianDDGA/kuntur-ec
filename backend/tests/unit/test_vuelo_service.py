from datetime import date, time
from decimal import Decimal

import pytest
from psycopg.errors import UniqueViolation

from services.vuelo_service import VueloService
from tests.factories import un_vuelo
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ConflictError, NotFoundError, ValidationError

HOY = date(2026, 11, 10)
NUEVO = {
    "codigo": " kt 801 ", "origen": " Quito ", "destino": "Esmeraldas", "fecha": "2026-12-28",
    "hora_salida": "08:00", "hora_llegada": "08:45", "precio": 75.5, "capacidad": 80,
}


def _servicio(db):
    return VueloService(db, hoy=lambda: HOY)


def _fila(**cambios):
    return un_vuelo(**cambios).to_dict()


# ---------------------------------------------------------------- buscar


def test_buscar_sin_filtros_solo_trae_vuelos_desde_hoy():
    db = BaseDatosFalsa(filas=[_fila(), _fila(id=11, codigo="KT102")])
    vuelos = _servicio(db).buscar()
    sql, params = db.cursor.consultas[0]
    assert "fecha >= %s" in sql and "ORDER BY fecha, hora_salida" in sql
    assert params == (HOY,)
    assert [v.id for v in vuelos] == [10, 11]


def test_buscar_con_filtros_usa_sql_parametrizado_sin_distinguir_mayusculas():
    db = BaseDatosFalsa()
    _servicio(db).buscar(origen="  quito ", destino="GUAYAQUIL", fecha="2026-12-01")
    sql, params = db.cursor.consultas[0]
    assert "lower(origen) = lower(%s)" in sql and "lower(destino) = lower(%s)" in sql
    assert params == (HOY, "quito", "GUAYAQUIL", date(2026, 12, 1))


def test_buscar_ignora_filtros_vacios():
    db = BaseDatosFalsa()
    _servicio(db).buscar(origen="", destino="  ", fecha="")
    assert db.cursor.consultas[0][1] == (HOY,)


def test_buscar_con_fecha_invalida_es_400():
    with pytest.raises(ValidationError, match="AAAA-MM-DD"):
        _servicio(BaseDatosFalsa()).buscar(fecha="01/12/2026")


# ---------------------------------------------------------------- detalle


def test_obtener_vuelo_existente_y_no_existente():
    assert _servicio(BaseDatosFalsa(filas=[_fila()])).obtener(10).codigo == "KEC-101"
    with pytest.raises(NotFoundError):
        _servicio(BaseDatosFalsa()).obtener(999)


# ---------------------------------------------------------------- crear


def test_crear_normaliza_datos_y_empieza_con_todos_los_asientos_libres():
    db = BaseDatosFalsa(filas=[_fila(codigo="KT801", destino="Esmeraldas", capacidad=80, asientos_disponibles=80)])
    _servicio(db).crear(NUEVO)
    sql, params = db.cursor.consultas[0]
    assert "INSERT INTO vuelos" in sql
    assert params == (
        "KT801", "Quito", "Esmeraldas", date(2026, 12, 28), time(8, 0), time(8, 45),
        Decimal("75.5"), 80, 80,
    )


@pytest.mark.parametrize(
    ("cambios", "mensaje"),
    [
        ({"codigo": ""}, "'codigo' es obligatorio"),
        ({"origen": None}, "'origen' es obligatorio"),
        ({"destino": "quito"}, "diferentes"),
        ({"fecha": "28-12-2026"}, "AAAA-MM-DD"),
        ({"fecha": "2026-11-09"}, "fecha pasada"),
        ({"hora_salida": "8am"}, "HH:MM"),
        ({"hora_llegada": "08:00"}, "distinta"),
        ({"precio": "gratis"}, "numérico"),
        ({"precio": True}, "numérico"),
        ({"precio": 0}, "mayor a 0"),
        ({"precio": "10.555"}, "2 decimales"),
        ({"capacidad": "80"}, "entero"),
        ({"capacidad": 0}, "mayor a 0"),
        ({"capacidad": 901}, "900"),
        ({"codigo": "K" * 11}, "10 caracteres"),
    ],
)
def test_crear_rechaza_datos_invalidos_sin_tocar_la_bd(cambios, mensaje):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match=mensaje):
        _servicio(db).crear(NUEVO | cambios)
    assert db.cursor.consultas == []


def test_crear_codigo_repetido_es_409():
    with pytest.raises(ConflictError, match="KT801"):
        _servicio(BaseDatosFalsa(error=UniqueViolation("dup"))).crear(NUEVO)
