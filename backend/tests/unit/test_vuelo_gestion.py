"""Editar y cancelar vuelos (administrador) y su efecto en búsqueda y reservas."""
from dataclasses import replace
from datetime import date, datetime, time
from decimal import Decimal

import pytest

from models import EstadoVuelo, Vuelo
from services.reserva_service import ReservaService
from services.vuelo_service import VueloService
from tests.factories import un_vuelo
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ConflictError, NotFoundError, ValidationError

AHORA = datetime(2026, 11, 22, 20, 17)  # el reloj de Ecuador en las pruebas
PROXIMO = un_vuelo(fecha=date(2026, 12, 1), version=3)  # 60 asientos, ninguno vendido
CON_RESERVAS = replace(PROXIMO, asientos_disponibles=55)  # 5 asientos vendidos
EDICION = {
    "origen": "Quito", "destino": "Guayaquil", "fecha": "2026-12-01", "hora_salida": "09:45",
    "hora_llegada": "10:40", "precio": "89.00", "version": 3,
}
MOTIVO = {"motivo": "Cierre del aeropuerto por ceniza volcánica.", "version": 3}


def _servicio(db):
    return VueloService(db, ahora=lambda: AHORA)


def _fila(vuelo: Vuelo, **cambios) -> dict:
    return replace(vuelo, **cambios).to_dict()


# ---------------------------------------------------------------- modelo


def test_un_vuelo_cancelado_exige_motivo_y_uno_programado_no_lo_tiene():
    with pytest.raises(ValidationError, match="motivo"):
        replace(PROXIMO, estado=EstadoVuelo.CANCELADO)
    with pytest.raises(ValidationError, match="motivo"):
        replace(PROXIMO, motivo_cancelacion="Mal clima en el destino")
    assert replace(PROXIMO, estado=EstadoVuelo.CANCELADO, motivo_cancelacion="Mal clima").esta_cancelado


def test_tiene_reservas_cuando_hay_asientos_vendidos():
    assert not PROXIMO.tiene_reservas
    assert CON_RESERVAS.tiene_reservas


# ---------------------------------------------------------------- búsqueda pública


def test_la_busqueda_y_la_portada_solo_muestran_vuelos_programados():
    db = BaseDatosFalsa(filas=[{"total": 0}])
    _servicio(db).buscar()
    assert "estado = 'programado'" in db.cursor.consultas[0][0]
    db = BaseDatosFalsa()
    _servicio(db).destinos()
    assert "estado = 'programado'" in db.cursor.consultas[0][0]


# ---------------------------------------------------------------- gestión


def test_gestion_incluye_si_ya_partio_y_los_asientos_vendidos():
    partido = un_vuelo(id=11, fecha=date(2026, 11, 22), hora_salida=time(20, 17))  # justo ahora
    db = BaseDatosFalsa(filas=[{"total": 2}, _fila(CON_RESERVAS), partido.to_dict()])
    datos = _servicio(db).gestion().to_dict()
    assert [(v["ya_partio"], v["asientos_vendidos"]) for v in datos["vuelos"]] == [(False, 5), (True, 0)]
    assert "WHERE" not in db.cursor.consultas[0][0]  # sin filtro: también cancelados y pasados


def test_gestion_filtra_por_estado():
    db = BaseDatosFalsa(filas=[{"total": 0}])
    _servicio(db).gestion(estado="cancelado")
    assert db.cursor.consultas[0] == ("SELECT count(*) AS total FROM vuelos WHERE estado = %s", ("cancelado",))


def test_gestion_rechaza_un_estado_desconocido():
    with pytest.raises(ValidationError, match="estado"):
        _servicio(BaseDatosFalsa()).gestion(estado="borrado")


# ---------------------------------------------------------------- editar


def test_editar_cambia_fecha_horas_y_precio_aunque_haya_reservas():
    editado = _fila(CON_RESERVAS, fecha=date(2026, 12, 2), hora_salida=time(7, 0), precio=Decimal("95.50"), version=4)
    db = BaseDatosFalsa(filas=[_fila(CON_RESERVAS), editado])
    vuelo = _servicio(db).editar(10, EDICION | {"fecha": "2026-12-02", "hora_salida": "07:00", "precio": "95.50"})
    assert (vuelo.fecha, vuelo.precio, vuelo.version) == (date(2026, 12, 2), Decimal("95.50"), 4)
    assert "FOR UPDATE" in db.cursor.consultas[0][0]
    sql, params = db.cursor.consultas[1]
    assert "WHERE id = %s AND version = %s" in sql
    assert params[-2:] == (10, 3)
    assert params[7] == 55  # los asientos vendidos se conservan


def test_editar_sin_cambios_no_toca_la_base():
    db = BaseDatosFalsa(filas=[_fila(PROXIMO)])
    assert _servicio(db).editar(10, EDICION) == PROXIMO
    assert len(db.cursor.consultas) == 1  # solo la lectura con bloqueo


def test_editar_con_version_vieja_es_409_con_la_version_actual():
    db = BaseDatosFalsa(filas=[_fila(PROXIMO, version=4)])
    with pytest.raises(ConflictError, match="Ya actualizaron") as error:
        _servicio(db).editar(10, EDICION)
    assert error.value.detalles["version_actual"] == 4


def test_editar_un_vuelo_que_no_existe_es_404():
    with pytest.raises(NotFoundError):
        _servicio(BaseDatosFalsa(filas=[None])).editar(99, EDICION)


def test_no_se_edita_un_vuelo_cancelado():
    cancelado = _fila(PROXIMO, estado=EstadoVuelo.CANCELADO, motivo_cancelacion="Mal clima")
    with pytest.raises(ConflictError, match="cancelado"):
        _servicio(BaseDatosFalsa(filas=[cancelado])).editar(10, EDICION)


def test_no_se_edita_un_vuelo_que_ya_partio():
    partido = _fila(PROXIMO, fecha=date(2026, 11, 22), hora_salida=time(20, 0))
    with pytest.raises(ValidationError, match="ya partió"):
        _servicio(BaseDatosFalsa(filas=[partido])).editar(10, EDICION | {"fecha": "2026-11-22", "hora_salida": "20:00"})


@pytest.mark.parametrize(
    ("cambios", "mensaje"),
    [
        ({"destino": "Cuenca"}, "no se puede cambiar la ruta"),
        ({"origen": "Loja"}, "no se puede cambiar la ruta"),
        ({"avion_id": 7}, "no se puede cambiar el avión"),
    ],
)
def test_con_asientos_vendidos_no_se_cambia_la_ruta_ni_el_avion(cambios, mensaje):
    db = BaseDatosFalsa(filas=[_fila(CON_RESERVAS)])
    with pytest.raises(ConflictError, match=mensaje):
        _servicio(db).editar(10, EDICION | cambios)


def test_la_ruta_se_compara_sin_distinguir_mayusculas():
    editado = _fila(CON_RESERVAS, origen="QUITO", destino="guayaquil", version=4)
    db = BaseDatosFalsa(filas=[_fila(CON_RESERVAS), editado])
    assert _servicio(db).editar(10, EDICION | {"origen": "QUITO", "destino": "guayaquil"}).version == 4


def test_sin_reservas_se_puede_cambiar_ruta_y_avion_y_la_capacidad_sigue_al_avion():
    editado = _fila(PROXIMO, destino="Cuenca", capacidad=72, asientos_disponibles=72, avion_id=7, version=4)
    db = BaseDatosFalsa(filas=[_fila(PROXIMO), {"filas": 18}, editado])
    vuelo = _servicio(db).editar(10, EDICION | {"destino": "Cuenca", "avion_id": 7})
    assert (vuelo.destino, vuelo.capacidad) == ("Cuenca", 72)
    params = db.cursor.consultas[2][1]
    assert params[6:9] == (72, 72, 7)  # capacidad, asientos libres y avión nuevos


def test_cambiar_a_un_avion_que_no_existe_es_404():
    with pytest.raises(NotFoundError, match="avión"):
        _servicio(BaseDatosFalsa(filas=[_fila(PROXIMO), None])).editar(10, EDICION | {"avion_id": 99})


@pytest.mark.parametrize(
    ("cambios", "mensaje"),
    [
        ({"fecha": "2026-11-21"}, "pasada"),
        ({"fecha": "2026-11-22", "hora_salida": "20:17"}, "ya pasó"),
        ({"fecha": "2029-01-01"}, "2 años"),
        ({"hora_llegada": "09:45"}, "distinta"),
        ({"destino": "quito"}, "diferentes"),
        ({"precio": "0"}, "precio"),
        ({"origen": "Qu1to"}, "letras"),
        ({"fecha": "01-12-2026"}, "AAAA-MM-DD"),
        ({"version": 0}, "version"),
        ({"codigo": "KT999"}, "no se pueden editar: codigo"),
        ({"capacidad": 10}, "no se pueden editar: capacidad"),
    ],
)
def test_editar_valida_igual_que_crear(cambios, mensaje):
    db = BaseDatosFalsa(filas=[_fila(PROXIMO)])
    with pytest.raises(ValidationError, match=mensaje):
        _servicio(db).editar(10, EDICION | cambios)


def test_editar_hoy_a_una_hora_futura_se_acepta():
    editado = _fila(PROXIMO, fecha=date(2026, 11, 22), hora_salida=time(23, 0), hora_llegada=time(23, 50))
    db = BaseDatosFalsa(filas=[_fila(PROXIMO), editado])
    cambios = {"fecha": "2026-11-22", "hora_salida": "23:00", "hora_llegada": "23:50"}
    assert _servicio(db).editar(10, EDICION | cambios).fecha == date(2026, 11, 22)


def test_editar_no_falla_si_la_base_ya_no_devuelve_la_fila():
    db = BaseDatosFalsa(filas=[_fila(PROXIMO), None])
    with pytest.raises(ConflictError, match="Ya actualizaron"):
        _servicio(db).editar(10, EDICION | {"precio": "90.00"})


# ---------------------------------------------------------------- cancelar


def test_cancelar_bloquea_reservas_y_vuelo_cancela_todo_y_libera_asientos():
    cancelado = _fila(
        CON_RESERVAS, estado=EstadoVuelo.CANCELADO, motivo_cancelacion=MOTIVO["motivo"],
        asientos_disponibles=60, version=4,
    )
    db = BaseDatosFalsa(filas=[_fila(CON_RESERVAS), cancelado])
    db.cursor.rowcount = 2
    resultado = _servicio(db).cancelar(10, MOTIVO)

    assert resultado.reservas_canceladas == 2
    assert resultado.vuelo.esta_cancelado and resultado.vuelo.asientos_disponibles == 60
    sql = [c[0] for c in db.cursor.consultas]
    assert "FROM reservas" in sql[0] and "FOR UPDATE" in sql[0]  # primero las reservas...
    assert "FROM vuelos" in sql[1] and "FOR UPDATE" in sql[1]    # ...luego el vuelo
    assert sql[2].startswith("UPDATE reservas SET estado")
    assert db.cursor.consultas[2][1] == ("cancelada", 10, "confirmada")
    assert sql[3].startswith("UPDATE reserva_asientos SET activo = FALSE")
    assert "asientos_disponibles = capacidad" in sql[4]
    assert db.cursor.consultas[4][1] == ("cancelado", MOTIVO["motivo"], 10)


def test_cancelar_un_vuelo_ya_cancelado_es_409():
    cancelado = _fila(PROXIMO, estado=EstadoVuelo.CANCELADO, motivo_cancelacion="Mal clima")
    with pytest.raises(ConflictError, match="cancelado"):
        _servicio(BaseDatosFalsa(filas=[cancelado])).cancelar(10, MOTIVO)


def test_cancelar_un_vuelo_que_ya_partio_es_400():
    partido = _fila(PROXIMO, fecha=date(2026, 11, 1))
    with pytest.raises(ValidationError, match="ya partió"):
        _servicio(BaseDatosFalsa(filas=[partido])).cancelar(10, MOTIVO)


def test_cancelar_con_version_vieja_es_409():
    with pytest.raises(ConflictError, match="Ya actualizaron"):
        _servicio(BaseDatosFalsa(filas=[_fila(PROXIMO, version=5)])).cancelar(10, MOTIVO)


@pytest.mark.parametrize(
    ("motivo", "mensaje"),
    [
        (None, "obligatorio"),
        ("   ", "obligatorio"),
        ("Clima", "al menos 10 letras"),
        ("1234567890 !!", "al menos 10 letras"),
        ("x" * 201, "200 caracteres"),
        ("Mal clima\x00 en destino", "caracteres"),
    ],
)
def test_el_motivo_de_cancelacion_se_valida(motivo, mensaje):
    with pytest.raises(ValidationError, match=mensaje):
        _servicio(BaseDatosFalsa()).cancelar(10, {"motivo": motivo, "version": 3})


def test_cancelar_sin_version_es_400():
    with pytest.raises(ValidationError, match="version"):
        _servicio(BaseDatosFalsa()).cancelar(10, {"motivo": MOTIVO["motivo"]})


# ---------------------------------------------------------------- efecto en las reservas


def test_no_se_puede_reservar_un_vuelo_cancelado():
    cancelado = _fila(PROXIMO, estado=EstadoVuelo.CANCELADO, motivo_cancelacion="Mal clima")
    tarifa = {"id": 1, "porcentaje": Decimal("15"), "vigente_desde": date(2024, 4, 1), "vigente_hasta": None}
    db = BaseDatosFalsa(filas=[tarifa, None, cancelado])  # el UPDATE no descuenta: se explica por qué
    from services.auth_service import Sesion
    from tests.factories import un_usuario

    with pytest.raises(ConflictError, match="cancelado por la aerolínea"):
        ReservaService(db, ahora=lambda: AHORA).crear(Sesion(un_usuario(), "tok"), {"vuelo_id": 10, "cantidad": 1})
