"""Asientos concretos contra la BD real de Supabase (se omiten si no hay DATABASE_URL).

Cada prueba usa un vuelo de 3 asientos (1A, 1B, 1C) y usuarios temporales que se borran al terminar.
"""
import os
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from threading import Barrier

import pytest
from dotenv import load_dotenv

from database import Database
from models import EstadoReserva, Usuario
from services.auth_service import Sesion
from services.reserva_service import ReservaService
from services.vuelo_service import VueloService
from utils.excepciones import ConflictError, ValidationError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

CODIGO = "TST02"
CORREOS = ("asientos.a@kuntur.test", "asientos.b@kuntur.test")


@pytest.fixture(scope="module")
def db():
    base = Database(URL)
    yield base
    base.cerrar()


def _limpiar(db):
    with db.transaccion() as cur:
        cur.execute("DELETE FROM reservas WHERE vuelo_id IN (SELECT id FROM vuelos WHERE codigo = %s)", (CODIGO,))
        cur.execute("DELETE FROM vuelos WHERE codigo = %s", (CODIGO,))
        cur.execute("DELETE FROM usuarios WHERE correo = ANY(%s)", (list(CORREOS),))


@pytest.fixture
def escenario(db):
    _limpiar(db)
    with db.transaccion() as cur:
        cur.execute(
            "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, capacidad, "
            "asientos_disponibles) VALUES (%s, 'Quito', 'Cuenca', current_date + 30, '08:00', '09:00', 100, 3, 3) "
            "RETURNING id",
            (CODIGO,),
        )
        vuelo_id = cur.fetchone()["id"]
        sesiones = []
        for correo in CORREOS:
            cur.execute(
                "INSERT INTO usuarios (nombre, correo, password_hash, rol) VALUES ('Prueba', %s, 'x', 'cliente') "
                "RETURNING id, nombre, correo, password_hash, rol, fecha_registro",
                (correo,),
            )
            sesiones.append(Sesion(Usuario.from_row(cur.fetchone()), "tok"))
    yield ReservaService(db), vuelo_id, sesiones
    _limpiar(db)


def _ocupados(db, vuelo_id):
    with db.transaccion() as cur:
        cur.execute("SELECT asiento FROM reserva_asientos WHERE vuelo_id = %s AND activo ORDER BY asiento", (vuelo_id,))
        return [f["asiento"] for f in cur.fetchall()]


def _libres(db, vuelo_id):
    with db.transaccion() as cur:
        cur.execute("SELECT asientos_disponibles FROM vuelos WHERE id = %s", (vuelo_id,))
        return cur.fetchone()["asientos_disponibles"]


def test_reservar_asientos_concretos_los_ocupa_y_el_mapa_los_muestra(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    detalle = servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1C", "1a"]})
    assert detalle.asientos == ("1A", "1C")
    assert _ocupados(db, vuelo_id) == ["1A", "1C"] and _libres(db, vuelo_id) == 1

    mapa = VueloService(db).asientos(vuelo_id)
    assert mapa == {"vuelo_id": vuelo_id, "capacidad": 3, "columnas": ["A", "B", "C", "D"], "ocupados": ["1A", "1C"]}
    assert servicio.obtener(ana, detalle.reserva.id).asientos == ("1A", "1C")
    assert servicio.listar(ana).reservas[0].asientos == ("1A", "1C")


def test_otro_cliente_no_puede_tomar_un_asiento_ocupado_y_nada_cambia(db, escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1A"]})
    with pytest.raises(ConflictError) as e:
        servicio.crear(beto, {"vuelo_id": vuelo_id, "asientos": ["1B", "1A"]})
    assert e.value.detalles == {"asientos_ocupados": ["1A"]}
    assert _libres(db, vuelo_id) == 2  # la transacción se deshizo: el contador no se movió
    assert _ocupados(db, vuelo_id) == ["1A"]
    assert servicio.listar(beto).total == 0


def test_asiento_que_no_existe_en_el_vuelo_es_400_y_no_descuenta(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    with pytest.raises(ValidationError, match="2A"):  # el vuelo de 3 asientos solo tiene 1A, 1B, 1C
        servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["2A"]})
    assert _libres(db, vuelo_id) == 3


def test_solo_cantidad_asigna_los_primeros_libres_sin_pisar_los_elegidos(db, escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1A"]})
    assert servicio.crear(beto, {"vuelo_id": vuelo_id, "cantidad": 2}).asientos == ("1B", "1C")


def test_cancelar_libera_los_asientos_pero_la_reserva_los_conserva_en_su_historial(db, escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    r = servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1A", "1B"]}).reserva
    cancelada = servicio.cancelar(ana, r.id)
    assert cancelada.reserva.estado is EstadoReserva.CANCELADA and cancelada.asientos == ("1A", "1B")
    assert _ocupados(db, vuelo_id) == [] and _libres(db, vuelo_id) == 3
    assert servicio.obtener(ana, r.id).asientos == ("1A", "1B")  # sigue en su historial
    assert servicio.crear(beto, {"vuelo_id": vuelo_id, "asientos": ["1A"]}).asientos == ("1A",)  # otro ya puede


def test_modificar_cambiando_lugares_ampliando_y_reduciendo(db, escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    servicio.crear(beto, {"vuelo_id": vuelo_id, "asientos": ["1C"]})
    r = servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1A"]}).reserva  # queda libre: 1B

    cambiada = servicio.modificar(ana, r.id, {"asientos": ["1B"], "version": 1})  # cambia de lugar
    assert cambiada.asientos == ("1B",) and cambiada.reserva.version == 2 and cambiada.reserva.total == r.total
    assert _ocupados(db, vuelo_id) == ["1B", "1C"] and _libres(db, vuelo_id) == 1

    with pytest.raises(ConflictError) as e:  # intenta pasarse al asiento de Beto
        servicio.modificar(ana, r.id, {"asientos": ["1C"], "version": 2})
    assert e.value.detalles == {"asientos_ocupados": ["1C"]}
    assert _ocupados(db, vuelo_id) == ["1B", "1C"]

    ampliada = servicio.modificar(ana, r.id, {"asientos": ["1A", "1B"], "version": 2})
    assert ampliada.asientos == ("1A", "1B") and ampliada.reserva.cantidad_asientos == 2
    assert ampliada.reserva.total == Decimal("230.00") and _libres(db, vuelo_id) == 0
    reducida = servicio.modificar(ana, r.id, {"asientos": ["1A"], "version": 3})
    assert reducida.asientos == ("1A",) and reducida.reserva.total == Decimal("115.00")
    assert _ocupados(db, vuelo_id) == ["1A", "1C"] and _libres(db, vuelo_id) == 1


def test_el_mismo_asiento_pedido_a_la_vez_lo_gana_una_sola_persona(db, escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    barrera = Barrier(8)

    def pedir(i):
        barrera.wait()
        try:
            servicio.crear(ana if i % 2 else beto, {"vuelo_id": vuelo_id, "asientos": ["1B"]})
            return 201
        except ConflictError:
            return 409

    with ThreadPoolExecutor(8) as ex:
        codigos = list(ex.map(pedir, range(8)))
    assert codigos.count(201) == 1 and codigos.count(409) == 7
    assert _ocupados(db, vuelo_id) == ["1B"] and _libres(db, vuelo_id) == 2


def test_la_base_impide_el_mismo_asiento_activo_dos_veces_aunque_se_salte_el_servicio(db, escenario):
    """Última defensa: el índice único parcial, por si algún día alguien inserta sin pasar por el servicio."""
    import psycopg

    servicio, vuelo_id, (ana, beto) = escenario
    r1 = servicio.crear(ana, {"vuelo_id": vuelo_id, "asientos": ["1A"]}).reserva
    r2 = servicio.crear(beto, {"vuelo_id": vuelo_id, "asientos": ["1B"]}).reserva
    with pytest.raises(psycopg.errors.UniqueViolation):
        with db.transaccion() as cur:
            cur.execute("INSERT INTO reserva_asientos (reserva_id, vuelo_id, asiento) VALUES (%s, %s, '1A')", (r2.id, vuelo_id))
    with pytest.raises(psycopg.errors.CheckViolation):  # formato inválido
        with db.transaccion() as cur:
            cur.execute("INSERT INTO reserva_asientos (reserva_id, vuelo_id, asiento) VALUES (%s, %s, '1E')", (r1.id, vuelo_id))


def test_la_base_no_admite_vuelos_de_mas_de_200_asientos(db):
    import psycopg

    with pytest.raises(psycopg.errors.CheckViolation):
        with db.transaccion() as cur:
            cur.execute(
                "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, capacidad, "
                "asientos_disponibles) VALUES ('TST03', 'Quito', 'Loja', current_date + 5, '08:00', '09:00', 50, 201, 201)"
            )
