"""Reservas contra la BD real de Supabase (se omiten si no hay DATABASE_URL).

Cada prueba usa un vuelo y usuarios temporales que se borran al terminar.
"""
import os
from decimal import Decimal

import pytest
from dotenv import load_dotenv

from database import Database
from models import EstadoReserva, Rol, Usuario
from services.auth_service import Sesion
from services.reserva_service import ReservaService
from utils.excepciones import ConflictError, NotFoundError, ValidationError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

CODIGO = "TST01"
CORREOS = ("reserva.a@kuntur.test", "reserva.b@kuntur.test")


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
    """Vuelo de 3 asientos a $100 y dos clientes."""
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


def _asientos(db, vuelo_id):
    with db.transaccion() as cur:
        cur.execute("SELECT asientos_disponibles FROM vuelos WHERE id = %s", (vuelo_id,))
        return cur.fetchone()["asientos_disponibles"]


def test_crear_descuenta_asientos_y_aplica_iva_vigente(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    detalle = servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 2})
    r = detalle.reserva
    assert (r.subtotal, r.iva_porcentaje, r.iva_valor, r.total) == (
        Decimal("200.00"), Decimal("15.00"), Decimal("30.00"), Decimal("230.00"),
    )
    assert r.estado is EstadoReserva.CONFIRMADA
    assert _asientos(db, vuelo_id) == 1


def test_sin_asientos_suficientes_es_409_y_no_cambia_nada(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 3})
    with pytest.raises(ConflictError, match="asientos"):
        servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 1})
    assert _asientos(db, vuelo_id) == 0


def test_vuelo_inexistente_es_404(escenario):
    servicio, _, (ana, _) = escenario
    with pytest.raises(NotFoundError):
        servicio.crear(ana, {"vuelo_id": 999999, "cantidad": 1})


def test_modificar_ampliar_reducir_y_sin_asientos(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    creada = servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 1}).reserva
    assert creada.version == 1

    ampliada = servicio.modificar(ana, creada.id, {"cantidad": 3, "version": 1}).reserva
    assert (ampliada.cantidad_asientos, ampliada.total, ampliada.version) == (3, Decimal("345.00"), 2)
    assert _asientos(db, vuelo_id) == 0

    reducida = servicio.modificar(ana, creada.id, {"cantidad": 2, "version": 2}).reserva
    assert (reducida.cantidad_asientos, reducida.total, reducida.version) == (2, Decimal("230.00"), 3)
    assert _asientos(db, vuelo_id) == 1

    with pytest.raises(ConflictError, match="ampliar"):
        servicio.modificar(ana, creada.id, {"cantidad": 4, "version": 3})
    assert _asientos(db, vuelo_id) == 1


def test_modificar_con_version_vieja_es_409_y_no_cambia_nada(db, escenario):
    """Dos personas leen la reserva (version 1); la primera la modifica y la segunda llega tarde."""
    servicio, vuelo_id, (ana, _) = escenario
    reserva_id = servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 1}).reserva.id

    servicio.modificar(ana, reserva_id, {"cantidad": 2, "version": 1})
    with pytest.raises(ConflictError, match="Ya actualizaron este registro") as error:
        servicio.modificar(ana, reserva_id, {"cantidad": 3, "version": 1})

    assert error.value.detalles == {"version_actual": 2}
    actual = servicio.obtener(ana, reserva_id).reserva
    assert (actual.cantidad_asientos, actual.version) == (2, 2)
    assert _asientos(db, vuelo_id) == 1


def test_cancelar_devuelve_asientos_y_no_se_puede_repetir(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    reserva_id = servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 2}).reserva.id

    cancelada = servicio.cancelar(ana, reserva_id).reserva
    assert (cancelada.estado, cancelada.version) == (EstadoReserva.CANCELADA, 2)
    assert _asientos(db, vuelo_id) == 3

    with pytest.raises(ConflictError, match="cancelada"):
        servicio.cancelar(ana, reserva_id)
    with pytest.raises(ConflictError, match="cancelada"):
        servicio.modificar(ana, reserva_id, {"cantidad": 1, "version": 2})
    assert _asientos(db, vuelo_id) == 3


def test_un_usuario_no_ve_ni_toca_reservas_ajenas(escenario):
    servicio, vuelo_id, (ana, beto) = escenario
    reserva_id = servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 1}).reserva.id

    assert [d.reserva.id for d in servicio.listar(ana).reservas] == [reserva_id]
    assert servicio.listar(ana).total == 1
    assert servicio.listar(beto).reservas == []
    for accion in (
        lambda: servicio.obtener(beto, reserva_id),
        lambda: servicio.modificar(beto, reserva_id, {"cantidad": 2, "version": 1}),
        lambda: servicio.cancelar(beto, reserva_id),
    ):
        with pytest.raises(NotFoundError):
            accion()


def test_no_se_reserva_un_vuelo_pasado(db, escenario):
    servicio, vuelo_id, (ana, _) = escenario
    with db.transaccion() as cur:
        cur.execute("UPDATE vuelos SET fecha = current_date - 1 WHERE id = %s", (vuelo_id,))
    with pytest.raises(ValidationError, match="ya partió"):
        servicio.crear(ana, {"vuelo_id": vuelo_id, "cantidad": 1})
    assert _asientos(db, vuelo_id) == 3
