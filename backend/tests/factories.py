"""Constructores de modelos válidos para las pruebas (evitan repetir datos)."""
from dataclasses import replace
from datetime import date, datetime, time, timezone
from decimal import Decimal
from typing import Any

from models import EstadoToken, Rol, TarifaIva, Token, Usuario, Vuelo


def un_usuario(**cambios: Any) -> Usuario:
    base = Usuario(
        id=1,
        nombre="Juan Pérez",
        correo="juan@correo.com",
        password_hash="$2b$12$hash",
        rol=Rol.CLIENTE,
        fecha_registro=datetime(2026, 6, 1, tzinfo=timezone.utc),
    )
    return replace(base, **cambios)


def un_vuelo(**cambios: Any) -> Vuelo:
    base = Vuelo(
        id=10,
        codigo="KEC-101",
        origen="Quito",
        destino="Guayaquil",
        fecha=date(2026, 6, 21),
        hora_salida=time(9, 45),
        hora_llegada=time(10, 40),
        precio=Decimal("89.00"),
        capacidad=60,
        asientos_disponibles=60,
    )
    return replace(base, **cambios)


def una_tarifa(porcentaje: str = "15", desde: date = date(2024, 4, 1), hasta: date | None = None) -> TarifaIva:
    return TarifaIva(id=1, porcentaje=Decimal(porcentaje), vigente_desde=desde, vigente_hasta=hasta)


def un_token(**cambios: Any) -> Token:
    base = Token(
        id=1,
        usuario_id=1,
        token="eyJ.jwt.firma",
        expiracion=datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc),
        estado=EstadoToken.ACTIVO,
    )
    return replace(base, **cambios)
