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
