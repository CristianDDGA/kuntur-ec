"""Asientos concretos: reglas de formato y servicio (sin base de datos real)."""
from datetime import date, datetime
from decimal import Decimal

import pytest

from models import Reserva, Rol
from services.auth_service import Sesion
from services.reserva_service import ReservaDetalle, ReservaService
from services.vuelo_service import VueloService
from tests.factories import un_usuario, un_vuelo
from tests.fakes import BaseDatosFalsa
from utils.asientos import COLUMNAS, etiqueta, etiquetas, lista_de_asientos, validar_existen
from utils.excepciones import ConflictError, NotFoundError, ValidationError

SESION = Sesion(un_usuario(id=1, rol=Rol.CLIENTE), "tok")
AHORA = datetime(2026, 11, 11, 13, 19, 40)
TARIFA = {"id": 1, "porcentaje": Decimal("15"), "vigente_desde": date(2024, 4, 1), "vigente_hasta": None}


def _servicio(db):
    return ReservaService(db, ahora=lambda: AHORA)


def _reserva_fila(cantidad):
    return {
        "id": 1, "usuario_id": 1, "vuelo_id": 10, "cantidad_asientos": cantidad,
        "subtotal": Decimal("89.00") * cantidad, "iva_porcentaje": Decimal("15"),
        "iva_valor": Decimal("13.35") * cantidad, "total": Decimal("102.35") * cantidad,
        "estado": "confirmada", "fecha_reserva": AHORA, "version": 1,
    }


def _vuelo(**cambios):
    return un_vuelo(fecha=date(2026, 12, 1), **cambios).to_dict()


# ---------------------------------------------------------------- etiquetas


def test_las_etiquetas_siguen_el_orden_fila_columna():
    assert COLUMNAS == "ABCD"
    assert etiquetas(6) == ["1A", "1B", "1C", "1D", "2A", "2B"]
    assert etiqueta(0) == "1A" and etiqueta(199) == "50D"


def test_un_vuelo_de_200_asientos_tiene_200_etiquetas_distintas():
    todas = etiquetas(200)
    assert len(set(todas)) == 200 and todas[-1] == "50D"


def test_validar_existen_segun_la_capacidad_del_vuelo():
    validar_existen(["1A", "2B"], 6)
    with pytest.raises(ValidationError, match="9D"):
        validar_existen(["9D"], 6)
    with pytest.raises(ValidationError, match="2C"):  # el vuelo de 6 asientos termina en 2B
        validar_existen(["2C"], 6)


def test_la_lista_de_asientos_se_normaliza_y_ordena():
    assert lista_de_asientos([" 10a", "2B", "1d"]) == ["1D", "2B", "10A"]


@pytest.mark.parametrize("malo", [
    None, "1A", 5, {}, [], [None], [1], [["1A"]], ["1A", "1A"], ["1a", "1A"], ["1E"], ["0A"], ["A1"], ["1"], ["A"],
    [""], [" "], ["1\nA"], ["1 A"], ["١A"], ["1😀"], ["1A;DROP"], ["x" * 500], ["1111A"], ["01A"], ["-1A"],
    [f"{i}A" for i in range(1, 12)],  # 11 asientos
])
def test_lista_de_asientos_rechaza_basura(malo):
    with pytest.raises(ValidationError):
        lista_de_asientos(malo)


def test_los_espacios_alrededor_se_recortan():
    assert lista_de_asientos([" 1A ", "2B	"]) == ["1A", "2B"]


def test_los_espacios_y_saltos_alrededor_se_recortan():
    assert lista_de_asientos([" 1A ", "2B\n"]) == ["1A", "2B"]


def test_el_maximo_de_diez_asientos_es_exacto():
    assert len(lista_de_asientos([f"{i}A" for i in range(1, 11)])) == 10


# ---------------------------------------------------------------- crear con asientos


def test_crear_con_asientos_guarda_exactamente_esos_y_descuenta_la_cantidad():
    db = BaseDatosFalsa(filas=[TARIFA, _vuelo(capacidad=60, asientos_disponibles=58), {"ocupados": []}, _reserva_fila(2)])
    detalle = _servicio(db).crear(SESION, {"vuelo_id": 10, "asientos": ["2b", "1A"]})
    assert detalle.asientos == ("1A", "2B")
    assert db.cursor.consultas[1][1][0] == 2  # se descuentan 2 asientos del contador
    sql, params = db.cursor.consultas[-1]
    assert "INSERT INTO reserva_asientos" in sql
    assert params == ((1, 10, "1A"), (1, 10, "2B"))
    assert "asiento = ANY" in db.cursor.consultas[2][0]  # antes de guardar se comprueba que estén libres


def test_crear_con_un_asiento_ocupado_es_409_y_dice_cual():
    db = BaseDatosFalsa(filas=[TARIFA, _vuelo(capacidad=60, asientos_disponibles=58), {"ocupados": ["2B"]}])
    with pytest.raises(ConflictError, match="otra persona") as e:
        _servicio(db).crear(SESION, {"vuelo_id": 10, "asientos": ["1A", "2B"]})
    assert e.value.detalles == {"asientos_ocupados": ["2B"]}
    assert not any("INSERT INTO reservas" in c[0] for c in db.cursor.consultas)  # no se creó nada


def test_crear_con_un_asiento_que_no_existe_en_ese_vuelo_es_400():
    db = BaseDatosFalsa(filas=[TARIFA, _vuelo(capacidad=6, asientos_disponibles=4)])
    with pytest.raises(ValidationError, match="9D"):
        _servicio(db).crear(SESION, {"vuelo_id": 10, "asientos": ["1A", "9D"]})


@pytest.mark.parametrize("asientos", [[], ["1E"], ["1A", "1A"], "1A", None, [f"{i}A" for i in range(1, 12)]])
def test_crear_con_asientos_invalidos_no_toca_la_bd(asientos):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError):
        _servicio(db).crear(SESION, {"vuelo_id": 10, "asientos": asientos})
    assert db.cursor.consultas == []


def test_modificar_con_asientos_invalidos_no_toca_la_bd():
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError):
        _servicio(db).modificar(SESION, 1, {"asientos": ["1E"], "version": 1})
    assert db.cursor.consultas == []


def test_el_detalle_incluye_los_asientos():
    detalle = ReservaDetalle(Reserva.from_row(_reserva_fila(2)), un_vuelo(), ("1A", "2B")).to_dict()
    assert detalle["asientos"] == ["1A", "2B"]


# ---------------------------------------------------------------- mapa de asientos


def test_el_mapa_dice_la_capacidad_las_columnas_y_los_ocupados():
    db = BaseDatosFalsa(filas=[{"capacidad": 120}, {"ocupados": ["2B", "3A"]}])
    assert VueloService(db).asientos(5) == {
        "vuelo_id": 5, "capacidad": 120, "columnas": ["A", "B", "C", "D"], "ocupados": ["2B", "3A"],
    }


def test_el_mapa_de_un_vuelo_inexistente_es_404():
    with pytest.raises(NotFoundError):
        VueloService(BaseDatosFalsa(filas=[None])).asientos(999)
