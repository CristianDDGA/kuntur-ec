import pytest

from models import Avion
from services.avion_service import AvionService
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ValidationError

CSV = b"matricula;modelo;filas\nHC-ABC;Airbus A320;30\nHC-XYZ;ATR 72;18\n"


def test_el_avion_calcula_su_capacidad_y_la_incluye_en_to_dict():
    avion = Avion(id=1, matricula="HC-ABC", modelo="A320", filas=30)
    assert avion.capacidad == 120 and avion.to_dict()["capacidad"] == 120


def test_validar_no_guarda_nada_y_marca_los_existentes():
    db = BaseDatosFalsa(filas=[{"matricula": "HC-XYZ"}])
    resumen = AvionService(db).validar(CSV)
    assert resumen["nuevos"] == 1 and resumen["existentes"] == ["HC-XYZ"] and resumen["errores"] == []
    assert not any("INSERT" in sql for sql, _ in db.cursor.consultas)
    assert resumen["vista_previa"][0]["capacidad"] == 120


def test_importar_guarda_solo_los_nuevos_en_una_transaccion():
    db = BaseDatosFalsa(filas=[{"matricula": "HC-XYZ"}])
    resultado = AvionService(db).importar(CSV)
    assert resultado == {"creados": 1, "omitidos": ["HC-XYZ"], "total_filas": 2}
    sql, params = db.cursor.consultas[-1]
    assert "INSERT INTO aviones" in sql and params == (("HC-ABC", "Airbus A320", 30),)


def test_importar_con_errores_no_toca_la_base():
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError) as e:
        AvionService(db).importar(b"matricula;modelo;filas\nHC-ABC;A320;99\n")
    assert e.value.detalles["errores"][0]["linea"] == 2
    assert db.cursor.consultas == []
