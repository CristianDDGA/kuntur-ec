from decimal import Decimal

import pytest

from models import Rol
from services.auth_service import Sesion
from services.reserva_service import ReservaDetalle, ReservaService
from tests.factories import un_usuario, un_vuelo
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ValidationError

SESION = Sesion(un_usuario(id=1, rol=Rol.CLIENTE), "tok")


@pytest.mark.parametrize(
    ("datos", "mensaje"),
    [
        ({"cantidad": 2}, "'vuelo_id' es obligatorio"),
        ({"vuelo_id": "1", "cantidad": 2}, "'vuelo_id' es obligatorio"),
        ({"vuelo_id": 1}, "'cantidad' es obligatorio"),
        ({"vuelo_id": 1, "cantidad": True}, "'cantidad' es obligatorio"),
        ({"vuelo_id": 1, "cantidad": 0}, "entre 1 y 10"),
        ({"vuelo_id": 1, "cantidad": 11}, "entre 1 y 10"),
    ],
)
def test_crear_rechaza_datos_invalidos_sin_tocar_la_bd(datos, mensaje):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match=mensaje):
        ReservaService(db).crear(SESION, datos)
    assert db.cursor.consultas == []


@pytest.mark.parametrize("cantidad", [0, 11, "3", None])
def test_modificar_rechaza_cantidad_invalida_sin_tocar_la_bd(cantidad):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError):
        ReservaService(db).modificar(SESION, 1, {"cantidad": cantidad, "version": 1})
    assert db.cursor.consultas == []


def test_el_detalle_incluye_un_resumen_del_vuelo_sin_datos_internos():
    from tests.factories import una_tarifa
    from models import Reserva

    reserva = Reserva.nueva(1, un_vuelo(), 2, una_tarifa())
    datos = ReservaDetalle(reserva, un_vuelo()).to_dict()
    assert datos["total"] == Decimal("204.70")
    assert datos["vuelo"]["codigo"] == "KEC-101"
    assert "asientos_disponibles" not in datos["vuelo"]


@pytest.mark.parametrize("version", [None, "1", True])
def test_modificar_exige_la_version_sin_tocar_la_bd(version):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match="'version' es obligatorio"):
        ReservaService(db).modificar(SESION, 1, {"cantidad": 2, "version": version})
    assert db.cursor.consultas == []


# ---------------------------------------------------------------- vuelo que ya partió

from datetime import date, datetime, time  # noqa: E402
from decimal import Decimal as _D  # noqa: E402

from utils.excepciones import ConflictError  # noqa: E402

AHORA = datetime(2026, 11, 11, 13, 19, 40)
TARIFA = {"id": 1, "porcentaje": _D("15"), "vigente_desde": date(2024, 4, 1), "vigente_hasta": None}


def _servicio(db):
    return ReservaService(db, ahora=lambda: AHORA)


def test_un_vuelo_parte_cuando_llega_su_hora_de_salida():
    s = _servicio(BaseDatosFalsa())
    hoy = date(2026, 11, 11)
    assert s._ya_partio(un_vuelo(fecha=date(2026, 11, 10), hora_salida=time(23, 59)))  # ayer
    assert s._ya_partio(un_vuelo(fecha=hoy, hora_salida=time(10, 0)))                  # hoy, antes
    assert s._ya_partio(un_vuelo(fecha=hoy, hora_salida=time(13, 19)))                 # justo ahora
    assert not s._ya_partio(un_vuelo(fecha=hoy, hora_salida=time(13, 20)))             # un minuto después
    assert not s._ya_partio(un_vuelo(fecha=date(2026, 11, 12), hora_salida=time(0, 1)))  # mañana


def test_crear_filtra_por_fecha_y_hora_de_salida_con_el_reloj_local():
    descontado = un_vuelo(fecha=date(2026, 12, 1), asientos_disponibles=58).to_dict()  # lo que devuelve el UPDATE
    reserva = {
        "id": 1, "usuario_id": 1, "vuelo_id": 10, "cantidad_asientos": 2, "subtotal": _D("178.00"),
        "iva_porcentaje": _D("15"), "iva_valor": _D("26.70"), "total": _D("204.70"),
        "estado": "confirmada", "fecha_reserva": AHORA, "version": 1,
    }
    db = BaseDatosFalsa(filas=[TARIFA, descontado, {"ocupados": []}, reserva])
    _servicio(db).crear(SESION, {"vuelo_id": 10, "cantidad": 2})
    sql, params = db.cursor.consultas[1]
    assert "current_date" not in sql  # ya no depende del reloj (UTC) de la base
    assert "fecha > %s OR (fecha = %s AND hora_salida > %s)" in sql
    assert params == (2, 10, 2, date(2026, 11, 11), date(2026, 11, 11), time(13, 19))


def test_crear_en_un_vuelo_que_ya_salio_hoy_explica_que_partio():
    partido = un_vuelo(fecha=date(2026, 11, 11), hora_salida=time(10, 0)).to_dict()
    db = BaseDatosFalsa(filas=[TARIFA, None, partido])  # el UPDATE no afectó filas
    with pytest.raises(ValidationError, match="ya partió"):
        _servicio(db).crear(SESION, {"vuelo_id": 10, "cantidad": 1})


def test_crear_sin_asientos_en_un_vuelo_futuro_es_409_no_partio():
    futuro = un_vuelo(fecha=date(2026, 12, 1), asientos_disponibles=0).to_dict()
    db = BaseDatosFalsa(filas=[TARIFA, None, futuro])
    with pytest.raises(ConflictError, match="suficientes asientos"):
        _servicio(db).crear(SESION, {"vuelo_id": 10, "cantidad": 1})


def test_crear_en_un_vuelo_inexistente_es_404():
    from utils.excepciones import NotFoundError

    with pytest.raises(NotFoundError):
        _servicio(BaseDatosFalsa(filas=[TARIFA, None, None])).crear(SESION, {"vuelo_id": 10, "cantidad": 1})


# ---------------------------------------------------------------- paginación del historial


def _fila_reserva(i):
    v = un_vuelo(fecha=date(2026, 12, 1)).to_dict()
    return {
        "id": i, "usuario_id": 1, "vuelo_id": 10, "cantidad_asientos": 1, "subtotal": _D("89.00"),
        "iva_porcentaje": _D("15"), "iva_valor": _D("13.35"), "total": _D("102.35"), "estado": "confirmada",
        "fecha_reserva": AHORA, "version": 1, **{f"v_{k}": val for k, val in v.items()},
    }


def test_listar_pagina_el_historial_y_solo_del_usuario():
    db = BaseDatosFalsa(filas=[{"total": 25}, _fila_reserva(1), _fila_reserva(2)])
    pagina = _servicio(db).listar(SESION, "3", "10")
    assert db.cursor.consultas[0][1] == (1,)                 # el conteo es del usuario de la sesión
    assert db.cursor.consultas[1][1] == (1, 10, 20)          # LIMIT 10 OFFSET 20
    d = pagina.to_dict()
    assert (d["total"], d["pagina"], d["por_pagina"], d["total_paginas"]) == (25, 3, 10, 3)
    assert [r["id"] for r in d["reservas"]] == [1, 2]


@pytest.mark.parametrize("campo,valor", [("pagina", "0"), ("pagina", "abc"), ("pagina", "1.5"), ("por_pagina", "51"), ("por_pagina", "-1")])
def test_listar_rechaza_paginacion_absurda_sin_tocar_la_bd(campo, valor):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match=campo):
        _servicio(db).listar(SESION, **{campo: valor})
    assert db.cursor.consultas == []


def test_listar_sin_reservas_devuelve_una_pagina_vacia():
    pagina = _servicio(BaseDatosFalsa(filas=[{"total": 0}])).listar(SESION)
    assert (pagina.total, pagina.reservas, pagina.to_dict()["total_paginas"]) == (0, [], 1)
