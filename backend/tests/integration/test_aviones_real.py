"""Aviones por CSV contra la BD real: importar, crear un vuelo con ese avión y reservar un asiento.

Usa matrículas y vuelos temporales que se borran al terminar.
"""
import os
from datetime import date, datetime, timedelta

import pytest
from dotenv import load_dotenv

from database import Database
from models import Rol, Usuario
from services.auth_service import Sesion
from services.avion_service import AvionService
from services.reserva_service import ReservaService
from services.vuelo_service import VueloService
from utils.excepciones import ConflictError, ValidationError

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")

MATRICULAS = ("TST-AV1", "TST-AV2")
CORREO = "aviones.real@kuntur.test"
CSV = "matricula;modelo;filas\nTST-AV1;Prueba 3 filas;3\nTST-AV2;Prueba 5 filas;5\n".encode()


@pytest.fixture(scope="module")
def db():
    base = Database(URL)
    yield base
    base.cerrar()


def _limpiar(db):
    with db.transaccion() as cur:
        cur.execute(
            "DELETE FROM reservas WHERE vuelo_id IN (SELECT id FROM vuelos WHERE avion_id IN "
            "(SELECT id FROM aviones WHERE matricula = ANY(%s)))",
            (list(MATRICULAS),),
        )
        cur.execute(
            "DELETE FROM vuelos WHERE avion_id IN (SELECT id FROM aviones WHERE matricula = ANY(%s))",
            (list(MATRICULAS),),
        )
        cur.execute("DELETE FROM aviones WHERE matricula = ANY(%s)", (list(MATRICULAS),))
        cur.execute("DELETE FROM usuarios WHERE correo = %s", (CORREO,))


@pytest.fixture(autouse=True)
def limpio(db):
    _limpiar(db)
    yield
    _limpiar(db)


def test_importar_es_idempotente_y_omite_las_matriculas_existentes(db):
    servicio = AvionService(db)
    assert servicio.importar(CSV)["creados"] == 2
    segunda = servicio.importar(CSV)
    assert segunda["creados"] == 0 and segunda["omitidos"] == ["TST-AV1", "TST-AV2"]
    asignados = {a.matricula: a for a in servicio.listar() if a.matricula in MATRICULAS}
    assert asignados["TST-AV1"].capacidad == 12 and asignados["TST-AV2"].capacidad == 20


def test_un_archivo_con_errores_no_importa_ni_una_fila(db):
    with pytest.raises(ValidationError):
        AvionService(db).importar(b"matricula;modelo;filas\nTST-AV1;Bien;3\nTST-AV2;Mal;99\n")
    assert [a for a in AvionService(db).listar() if a.matricula in MATRICULAS] == []


def test_un_vuelo_con_avion_toma_su_capacidad_y_se_puede_reservar(db):
    AvionService(db).importar(CSV)
    avion = next(a for a in AvionService(db).listar() if a.matricula == "TST-AV1")  # 3 filas = 12 asientos
    manana = date.today() + timedelta(days=30)
    vuelos = VueloService(db, ahora=datetime.now)
    vuelo = vuelos.crear({
        "origen": "Quito", "destino": "Cuenca", "fecha": manana.isoformat(), "hora_salida": "08:00",
        "hora_llegada": "09:00", "precio": 50, "avion_id": avion.id, "capacidad": 999,  # la capacidad enviada se ignora
    })
    assert vuelo.capacidad == 12 and vuelo.asientos_disponibles == 12 and vuelo.avion_id == avion.id
    assert vuelos.asientos(vuelo.id)["capacidad"] == 12

    with db.transaccion() as cur:
        cur.execute(
            "INSERT INTO usuarios (nombre, correo, password_hash, rol) VALUES ('Prueba', %s, 'x', 'cliente') "
            "RETURNING id, nombre, correo, password_hash, rol, fecha_registro",
            (CORREO,),
        )
        sesion = Sesion(Usuario.from_row(cur.fetchone()), "tok")
    reservas = ReservaService(db)
    assert reservas.crear(sesion, {"vuelo_id": vuelo.id, "asientos": ["3D"]}).asientos == ("3D",)  # último asiento
    with pytest.raises(ValidationError):  # la fila 4 no existe en un avión de 3 filas
        reservas.crear(sesion, {"vuelo_id": vuelo.id, "asientos": ["4A"]})


def test_no_se_puede_borrar_un_avion_con_vuelos(db):
    AvionService(db).importar(CSV)
    avion = next(a for a in AvionService(db).listar() if a.matricula == "TST-AV1")
    VueloService(db).crear({
        "origen": "Quito", "destino": "Cuenca", "fecha": (date.today() + timedelta(days=30)).isoformat(),
        "hora_salida": "08:00", "hora_llegada": "09:00", "precio": 50, "avion_id": avion.id,
    })
    with pytest.raises(Exception):
        with db.transaccion() as cur:
            cur.execute("DELETE FROM aviones WHERE id = %s", (avion.id,))
