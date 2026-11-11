from datetime import date, datetime, time
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


AHORA = datetime(2026, 11, 10, 13, 19, 45)
HORA = AHORA.time().replace(second=0)  # 13:19


def _en_vivo(db):
    """Servicio con el reloj fijo en AHORA (10-nov-2026 13:19)."""
    return VueloService(db, ahora=lambda: AHORA)


def _pagina(filas, total=None):
    """Lo que devuelve la BD en una búsqueda: primero el conteo, después las filas."""
    return [{"total": len(filas) if total is None else total}, *filas]


def test_buscar_sin_filtros_solo_trae_vuelos_que_aun_no_parten():
    db = BaseDatosFalsa(filas=_pagina([_fila(), _fila(id=11, codigo="KT102")]))
    pagina = _servicio(db).buscar()
    sql, params = db.cursor.consultas[1]
    assert "fecha > %s OR (fecha = %s AND hora_salida > %s)" in sql and "ORDER BY fecha, hora_salida" in sql
    assert params[:2] == (HOY, HOY)
    assert [v.id for v in pagina.vuelos] == [10, 11]
    assert (pagina.total, pagina.pagina, pagina.por_pagina, pagina.total_paginas) == (2, 1, 10, 1)


def test_buscar_con_filtros_usa_sql_parametrizado_sin_distinguir_mayusculas():
    db = BaseDatosFalsa(filas=_pagina([]))
    _servicio(db).buscar(origen="  quito ", destino="GUAYAQUIL", fecha="2026-12-01")
    sql, params = db.cursor.consultas[1]
    assert "lower(origen) = lower(%s)" in sql and "lower(destino) = lower(%s)" in sql
    assert params[3:6] == ("quito", "GUAYAQUIL", date(2026, 12, 1))


def test_buscar_ignora_filtros_vacios():
    db = BaseDatosFalsa(filas=_pagina([]))
    _servicio(db).buscar(origen="", destino="  ", fecha="")
    assert len(db.cursor.consultas[0][1]) == 3  # solo la condición de "aún no parte"


def test_buscar_con_fecha_invalida_es_400():
    with pytest.raises(ValidationError, match="AAAA-MM-DD"):
        _servicio(BaseDatosFalsa()).buscar(fecha="01/12/2026")


def test_hoy_solo_se_ven_los_vuelos_con_salida_posterior_a_la_hora_actual():
    db = BaseDatosFalsa(filas=_pagina([]))
    _en_vivo(db).buscar()
    assert db.cursor.consultas[0][1] == (AHORA.date(), AHORA.date(), HORA)


# ---------------------------------------------------------------- paginación


def test_paginacion_calcula_limite_y_desplazamiento():
    db = BaseDatosFalsa(filas=_pagina([_fila()], total=25))
    pagina = _servicio(db).buscar(pagina="3", por_pagina="10")
    assert db.cursor.consultas[1][1][-2:] == (10, 20)  # LIMIT 10 OFFSET 20
    assert (pagina.pagina, pagina.por_pagina, pagina.total, pagina.total_paginas) == (3, 10, 25, 3)


def test_paginacion_por_defecto_es_pagina_1_de_10():
    db = BaseDatosFalsa(filas=_pagina([]))
    _servicio(db).buscar()
    assert db.cursor.consultas[1][1][-2:] == (10, 0)


def test_sin_resultados_hay_una_pagina_vacia():
    pagina = _servicio(BaseDatosFalsa(filas=_pagina([]))).buscar()
    assert (pagina.total, pagina.total_paginas, pagina.vuelos) == (0, 1, [])


def test_to_dict_de_la_pagina():
    d = _servicio(BaseDatosFalsa(filas=_pagina([_fila()], total=11))).buscar().to_dict()
    assert (d["total"], d["pagina"], d["por_pagina"], d["total_paginas"]) == (11, 1, 10, 2)
    assert d["vuelos"][0]["id"] == 10


@pytest.mark.parametrize("campo,valor", [
    ("pagina", "0"), ("pagina", "-1"), ("pagina", "abc"), ("pagina", "1.5"), ("pagina", "1e3"),
    ("pagina", "100001"), ("pagina", "٣"), ("pagina", "99999999999999999999999"),
    ("por_pagina", "0"), ("por_pagina", "51"), ("por_pagina", "mil"), ("por_pagina", "-5"),
])
def test_paginacion_rechaza_valores_absurdos_sin_tocar_la_bd(campo, valor):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match=campo):
        _servicio(db).buscar(**{campo: valor})
    assert db.cursor.consultas == []


def test_paginacion_acepta_los_limites():
    _servicio(BaseDatosFalsa(filas=_pagina([]))).buscar(pagina="100000", por_pagina="50")


# ---------------------------------------------------------------- hora de salida


def _hoy_a_las(hora):
    return NUEVO | {"fecha": "2026-11-10", "hora_salida": hora, "hora_llegada": "23:59"}


@pytest.mark.parametrize("hora", ["10:00", "13:19", "00:00"])
def test_crear_hoy_con_hora_ya_pasada_es_400(hora):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match="13:19"):
        _en_vivo(db).crear(_hoy_a_las(hora))
    assert db.cursor.consultas == []


def test_crear_hoy_con_hora_futura_se_acepta():
    db = BaseDatosFalsa(filas=[_fila(fecha=date(2026, 11, 10))])
    _en_vivo(db).crear(_hoy_a_las("13:20"))
    assert len(db.cursor.consultas) == 1


def test_crear_otro_dia_no_mira_la_hora():
    db = BaseDatosFalsa(filas=[_fila()])
    _en_vivo(db).crear(NUEVO | {"fecha": "2026-11-11", "hora_salida": "00:01", "hora_llegada": "01:00"})


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
        ({"capacidad": 0}, "entre 1 y 900"),
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


# ---------------------------------------------------------------- código generado


SIN_CODIGO = {k: v for k, v in NUEVO.items() if k != "codigo"}


def test_crear_sin_codigo_lo_genera_la_base_y_devuelve_el_vuelo():
    db = BaseDatosFalsa(filas=[_fila(codigo="KT101")])
    vuelo = _servicio(db).crear(SIN_CODIGO)
    assert vuelo.codigo == "KT101"
    sql, params = db.cursor.consultas[0]
    assert "'KT' ||" in sql and "FROM vuelos" in sql
    assert "KT" not in params  # el código no viaja como parámetro: lo calcula el INSERT


@pytest.mark.parametrize("vacio", [None, ""])
def test_codigo_vacio_tambien_se_genera(vacio):
    db = BaseDatosFalsa(filas=[_fila(codigo="KT102")])
    assert _servicio(db).crear(SIN_CODIGO | {"codigo": vacio}).codigo == "KT102"


def test_si_dos_crean_a_la_vez_reintenta_con_el_siguiente_codigo():
    class CursorChoca:
        def __init__(self):
            self.intentos = 0
            self.consultas = []

        def execute(self, sql, params=()):
            self.consultas.append((sql, params))
            self.intentos += 1
            if self.intentos == 1:
                raise UniqueViolation("otro tomó KT101")

        def fetchone(self):
            return _fila(codigo="KT102")

    class Db:
        cursor = CursorChoca()

        from contextlib import contextmanager

        @contextmanager
        def transaccion(self):
            yield self.cursor

    db = Db()
    assert _servicio(db).crear(SIN_CODIGO).codigo == "KT102"
    assert db.cursor.intentos == 2


def test_si_siempre_choca_se_rinde_con_409():
    with pytest.raises(ConflictError, match="código de vuelo"):
        _servicio(BaseDatosFalsa(error=UniqueViolation("dup"))).crear(SIN_CODIGO)
