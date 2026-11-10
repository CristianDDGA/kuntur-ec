"""Tabla `reservas`.

Guarda una "foto" de los montos al momento de reservar (subtotal, IVA aplicado
y total) para que la factura no cambie si después cambia el precio o el IVA.
"""
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Self

from models.base import Modelo, requerir
from models.tarifa_iva import TarifaIva
from models.vuelo import Vuelo
from utils.excepciones import ConflictError


class EstadoReserva(StrEnum):
    CONFIRMADA = "confirmada"
    CANCELADA = "cancelada"


@dataclass(frozen=True)
class Reserva(Modelo):
    id: int | None
    usuario_id: int
    vuelo_id: int
    cantidad_asientos: int
    subtotal: Decimal
    iva_porcentaje: Decimal
    iva_valor: Decimal
    total: Decimal
    estado: EstadoReserva
    fecha_reserva: datetime | None
    version: int = 1  # control de concurrencia optimista

    @classmethod
    def nueva(cls, usuario_id: int, vuelo: Vuelo, cantidad: int, tarifa: TarifaIva) -> Self:
        """Crea una reserva confirmada calculando los montos con la tarifa de IVA vigente."""
        if not vuelo.tiene_asientos(cantidad):
            raise ConflictError("No hay suficientes asientos disponibles en el vuelo.")
        desglose = tarifa.calcular(vuelo.subtotal(cantidad))
        return cls(
            id=None,
            usuario_id=usuario_id,
            vuelo_id=vuelo.id,
            cantidad_asientos=cantidad,
            subtotal=desglose.subtotal,
            iva_porcentaje=desglose.iva_porcentaje,
            iva_valor=desglose.iva_valor,
            total=desglose.total,
            estado=EstadoReserva.CONFIRMADA,
            fecha_reserva=None,
        )

    @property
    def esta_cancelada(self) -> bool:
        return self.estado is EstadoReserva.CANCELADA

    def _validar(self) -> None:
        requerir(self.cantidad_asientos > 0, "La reserva debe tener al menos 1 asiento.")
        requerir(min(self.subtotal, self.iva_valor) >= 0, "Los montos no pueden ser negativos.")
        requerir(
            self.total == self.subtotal + self.iva_valor,
            "El total debe ser igual al subtotal más el IVA.",
        )
        requerir(isinstance(self.estado, EstadoReserva), "El estado de la reserva no es válido.")
