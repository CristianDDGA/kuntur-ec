from datetime import date, datetime, timezone
from decimal import Decimal

import pytest

from models import EstadoReserva, EstadoToken, Reserva, Rol, TarifaIva, Token, Usuario, Vuelo
from tests.factories import un_token, un_usuario, un_vuelo, una_tarifa
from utils.excepciones import ConflictError, ValidationError

# ---------------------------------------------------------------- Usuario


def test_usuario_desde_fila_convierte_el_rol():
    fila = {
        "id": 5, "nombre": "Ana", "correo": "ana@correo.com",
        "password_hash": "$2b$hash", "rol": "admin", "fecha_registro": None,
    }
    usuario = Usuario.from_row(fila)
    assert usuario.rol is Rol.ADMIN
    assert usuario.es_admin


def test_usuario_to_dict_nunca_expone_la_contrasena():
    datos = un_usuario().to_dict()
    assert "password_hash" not in datos
    assert datos["correo"] == "juan@correo.com"


@pytest.mark.parametrize(
    "cambios",
    [{"nombre": "  "}, {"correo": "sin-arroba"}, {"password_hash": ""}],
)
def test_usuario_invalido(cambios):
    with pytest.raises(ValidationError):
        un_usuario(**cambios)


# ---------------------------------------------------------------- Vuelo


def test_vuelo_desde_fila_convierte_el_precio_a_decimal():
    fila = un_vuelo().to_dict() | {"precio": 89.5}
    assert Vuelo.from_row(fila).precio == Decimal("89.5")


def test_vuelo_asientos_y_subtotal():
    vuelo = un_vuelo(asientos_disponibles=2)
    assert vuelo.tiene_asientos(2)
    assert not vuelo.tiene_asientos(3)
    assert not vuelo.tiene_asientos(0)
    assert vuelo.subtotal(2) == Decimal("178.00")


@pytest.mark.parametrize(
    ("cambios", "mensaje"),
    [
        ({"destino": " quito "}, "diferentes"),
        ({"precio": Decimal("0")}, "precio"),
        ({"capacidad": 0, "asientos_disponibles": 0}, "capacidad"),
        ({"asientos_disponibles": 61}, "asientos"),
        ({"asientos_disponibles": -1}, "asientos"),
        ({"codigo": ""}, "código"),
    ],
)
def test_vuelo_invalido(cambios, mensaje):
    with pytest.raises(ValidationError, match=mensaje):
        un_vuelo(**cambios)


# ---------------------------------------------------------------- Tarifa de IVA


def test_iva_15_coincide_con_el_comprobante_de_la_infografia():
    # 2 pasajeros Quito -> Guayaquil: subtotal 178.00, IVA 26.70, total 204.70
    desglose = una_tarifa("15").calcular(un_vuelo().subtotal(2))
    assert desglose.subtotal == Decimal("178.00")
    assert desglose.iva_valor == Decimal("26.70")
    assert desglose.total == Decimal("204.70")


def test_si_el_iva_cambia_a_12_el_calculo_usa_la_nueva_tarifa():
    desglose = una_tarifa("12").calcular(Decimal("178.00"))
    assert desglose.iva_porcentaje == Decimal("12")
    assert desglose.iva_valor == Decimal("21.36")
    assert desglose.total == Decimal("199.36")


def test_iva_redondea_al_centavo_hacia_arriba_en_la_mitad():
    assert una_tarifa("15").calcular(Decimal("0.50")).iva_valor == Decimal("0.08")  # 0.075


def test_vigencia_de_tarifas():
    anterior = una_tarifa("15", desde=date(2024, 4, 1), hasta=date(2027, 1, 1))
    nueva = una_tarifa("12", desde=date(2027, 1, 1))

    assert anterior.vigente_en(date(2026, 12, 31))
    assert not anterior.vigente_en(date(2027, 1, 1))
    assert nueva.vigente_en(date(2027, 1, 1))
    assert not nueva.vigente_en(date(2026, 12, 31))


@pytest.mark.parametrize(
    "kwargs",
    [
        {"porcentaje": Decimal("-1"), "vigente_desde": date(2026, 1, 1), "vigente_hasta": None},
        {"porcentaje": Decimal("101"), "vigente_desde": date(2026, 1, 1), "vigente_hasta": None},
        {"porcentaje": Decimal("12"), "vigente_desde": date(2026, 1, 1), "vigente_hasta": date(2026, 1, 1)},
    ],
)
def test_tarifa_invalida(kwargs):
    with pytest.raises(ValidationError):
        TarifaIva(id=None, **kwargs)


# ---------------------------------------------------------------- Reserva


def test_reserva_nueva_guarda_la_foto_del_iva_aplicado():
    reserva = Reserva.nueva(usuario_id=1, vuelo=un_vuelo(), cantidad=2, tarifa=una_tarifa("15"))

    assert reserva.estado is EstadoReserva.CONFIRMADA
    assert (reserva.subtotal, reserva.iva_porcentaje, reserva.iva_valor, reserva.total) == (
        Decimal("178.00"), Decimal("15"), Decimal("26.70"), Decimal("204.70"),
    )


def test_reserva_antigua_no_cambia_cuando_cambia_el_iva():
    antigua = Reserva.nueva(1, un_vuelo(), 2, una_tarifa("15"))
    nueva = Reserva.nueva(1, un_vuelo(), 2, una_tarifa("12"))

    assert antigua.iva_porcentaje == Decimal("15") and antigua.total == Decimal("204.70")
    assert nueva.iva_porcentaje == Decimal("12") and nueva.total == Decimal("199.36")


def test_reserva_sin_asientos_suficientes_es_conflicto():
    with pytest.raises(ConflictError):
        Reserva.nueva(1, un_vuelo(asientos_disponibles=1), 2, una_tarifa())


def test_reserva_desde_fila_y_to_dict():
    reserva = Reserva.nueva(1, un_vuelo(), 1, una_tarifa())
    fila = reserva.to_dict() | {"id": 58, "estado": "cancelada", "total": "102.35"}
    copia = Reserva.from_row(fila)

    assert copia.esta_cancelada
    assert copia.total == Decimal("102.35")


@pytest.mark.parametrize(
    "cambios",
    [{"cantidad_asientos": 0}, {"total": Decimal("1.00")}, {"iva_valor": Decimal("-1"), "total": Decimal("88.00")}],
)
def test_reserva_invalida(cambios):
    base = Reserva.nueva(1, un_vuelo(), 1, una_tarifa()).to_dict()
    with pytest.raises(ValidationError):
        Reserva(**(base | cambios))


# ---------------------------------------------------------------- Token


def test_token_validez_y_privacidad():
    token = un_token()
    antes = datetime(2026, 6, 1, 11, 0, tzinfo=timezone.utc)
    despues = datetime(2026, 6, 1, 13, 0, tzinfo=timezone.utc)

    assert token.es_valido(antes)
    assert not token.es_valido(despues)
    assert not un_token(estado=EstadoToken.REVOCADO).es_valido(antes)
    assert "token" not in token.to_dict()


def test_token_desde_fila_convierte_el_estado():
    fila = {"id": 1, "usuario_id": 1, "token": "x.y.z",
            "expiracion": datetime(2026, 6, 1, tzinfo=timezone.utc), "estado": "revocado"}
    assert Token.from_row(fila).estado is EstadoToken.REVOCADO
