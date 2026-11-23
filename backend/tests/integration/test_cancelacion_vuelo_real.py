"""Cancelar un vuelo mientras la gente reserva, contra la BD real (se omiten si no hay DATABASE_URL).

Lo que debe cumplirse SIEMPRE, por mucho que se crucen las peticiones:
- ninguna reserva queda confirmada en un vuelo cancelado;
- ningún asiento queda ocupado y el contador vuelve a la capacidad;
- cada reserva que se intentó termina en "cancelada con el vuelo" o en "rechazada: vuelo cancelado".

Cada prueba usa un vuelo y usuarios temporales que se borran al terminar.
"""
import os
import threading
from datetime import date, timedelta

import pytest
from dotenv import load_dotenv

from database import Database
from models import EstadoVuelo, Usuario
from services.auth_service import Sesion
from services.reserva_service import ReservaService
from services.vuelo_service import VueloService
from utils.excepciones import ConflictError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

CODIGO = "TST03"
CLIENTES = 8
CORREOS = tuple(f"cancela.{i}@kuntur.test" for i in range(CLIENTES))
MOTIVO = {"motivo": "Cierre del aeropuerto por ceniza volcánica"}


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
    """Vuelo de 40 asientos dentro de 30 días y 8 clientes."""
    _limpiar(db)
    with db.transaccion() as cur:
        cur.execute(
            "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, capacidad, "
            "asientos_disponibles) VALUES (%s, 'Quito', 'Loja', %s, '08:00', '09:00', 100, 40, 40) RETURNING id",
            (CODIGO, date.today() + timedelta(days=30)),
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
    yield ReservaService(db), VueloService(db), vuelo_id, sesiones
    _limpiar(db)


def _estado_final(db, vuelo_id) -> dict:
    with db.transaccion() as cur:
        cur.execute("SELECT estado, capacidad, asientos_disponibles, version FROM vuelos WHERE id = %s", (vuelo_id,))
        vuelo = cur.fetchone()
        cur.execute("SELECT count(*) AS n FROM reservas WHERE vuelo_id = %s AND estado = 'confirmada'", (vuelo_id,))
        confirmadas = cur.fetchone()["n"]
        cur.execute("SELECT count(*) AS n FROM reserva_asientos WHERE vuelo_id = %s AND activo", (vuelo_id,))
        ocupados = cur.fetchone()["n"]
    return {**vuelo, "confirmadas": confirmadas, "ocupados": ocupados}


def _version(db, vuelo_id) -> int:
    with db.transaccion() as cur:
        cur.execute("SELECT version FROM vuelos WHERE id = %s", (vuelo_id,))
        return cur.fetchone()["version"]


def test_reservar_no_invalida_la_version_que_ve_el_administrador(db, escenario):
    reservas, vuelos, vuelo_id, sesiones = escenario
    version_leida = _version(db, vuelo_id)
    detalle = reservas.crear(sesiones[0], {"vuelo_id": vuelo_id, "cantidad": 2})
    reservas.modificar(sesiones[0], detalle.reserva.id, {"cantidad": 3, "version": 1})
    otra = reservas.crear(sesiones[1], {"vuelo_id": vuelo_id, "cantidad": 1})
    reservas.cancelar(sesiones[1], otra.reserva.id)
    assert _version(db, vuelo_id) == version_leida  # las reservas no tocan la versión del vuelo

    resultado = vuelos.cancelar(vuelo_id, MOTIVO | {"version": version_leida})
    assert resultado.reservas_canceladas == 1  # la de 3 asientos (la otra ya estaba cancelada)
    final = _estado_final(db, vuelo_id)
    assert (final["estado"], final["asientos_disponibles"], final["confirmadas"], final["ocupados"]) == (
        "cancelado", 40, 0, 0,
    )


def test_cancelar_mientras_todos_reservan_no_deja_nada_a_medias(db, escenario):
    reservas, vuelos, vuelo_id, sesiones = escenario
    version = _version(db, vuelo_id)
    salida = threading.Barrier(CLIENTES + 1)
    resultados: dict[str, object] = {}

    def reservar(i, sesion):
        salida.wait()
        try:
            resultados[f"r{i}"] = reservas.crear(sesion, {"vuelo_id": vuelo_id, "cantidad": 2})
        except Exception as e:  # noqa: BLE001 - se clasifica abajo
            resultados[f"r{i}"] = e

    def cancelar():
        salida.wait()
        try:
            resultados["cancelacion"] = vuelos.cancelar(vuelo_id, MOTIVO | {"version": version})
        except Exception as e:  # noqa: BLE001
            resultados["cancelacion"] = e

    hilos = [threading.Thread(target=reservar, args=(i, s)) for i, s in enumerate(sesiones)]
    hilos.append(threading.Thread(target=cancelar))
    for h in hilos:
        h.start()
    for h in hilos:
        h.join(timeout=60)

    cancelacion = resultados["cancelacion"]
    assert not isinstance(cancelacion, Exception), cancelacion  # reservar nunca bloquea la cancelación
    hechas = [r for k, r in resultados.items() if k.startswith("r") and not isinstance(r, Exception)]
    rechazadas = [r for k, r in resultados.items() if k.startswith("r") and isinstance(r, Exception)]
    assert len(hechas) + len(rechazadas) == CLIENTES
    # Las que llegaron tarde se rechazan explicando que el vuelo fue cancelado (nada de errores 500).
    assert all(isinstance(e, ConflictError) and "cancelado" in str(e) for e in rechazadas)
    # Las que alcanzaron a reservar quedaron canceladas junto con el vuelo.
    assert cancelacion.reservas_canceladas == len(hechas)

    final = _estado_final(db, vuelo_id)
    assert final["estado"] == EstadoVuelo.CANCELADO.value
    assert final["confirmadas"] == 0
    assert final["ocupados"] == 0
    assert final["asientos_disponibles"] == final["capacidad"]


def test_despues_de_cancelar_no_se_reserva_ni_se_modifica(db, escenario):
    reservas, vuelos, vuelo_id, sesiones = escenario
    detalle = reservas.crear(sesiones[0], {"vuelo_id": vuelo_id, "cantidad": 1})
    vuelos.cancelar(vuelo_id, MOTIVO | {"version": _version(db, vuelo_id)})

    with pytest.raises(ConflictError, match="cancelado"):
        reservas.crear(sesiones[1], {"vuelo_id": vuelo_id, "cantidad": 1})
    with pytest.raises(ConflictError, match="cancelado"):
        reservas.modificar(sesiones[0], detalle.reserva.id, {"cantidad": 2, "version": 2})
    with pytest.raises(ConflictError, match="cancelado"):
        reservas.cancelar(sesiones[0], detalle.reserva.id)
    assert _estado_final(db, vuelo_id)["asientos_disponibles"] == 40


def test_dos_administradores_cancelan_a_la_vez_y_solo_uno_lo_logra(db, escenario):
    _, vuelos, vuelo_id, _ = escenario
    version = _version(db, vuelo_id)
    salida = threading.Barrier(2)
    resultados = []

    def cancelar():
        salida.wait()
        try:
            resultados.append(vuelos.cancelar(vuelo_id, MOTIVO | {"version": version}))
        except ConflictError as e:
            resultados.append(e)

    hilos = [threading.Thread(target=cancelar) for _ in range(2)]
    for h in hilos:
        h.start()
    for h in hilos:
        h.join(timeout=60)

    assert sum(isinstance(r, ConflictError) for r in resultados) == 1
    assert _version(db, vuelo_id) == version + 1  # se aplicó una sola vez
