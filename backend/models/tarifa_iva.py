"""Tabla `tarifas_iva`: historial del porcentaje de IVA.

El IVA puede cambiar con el tiempo (p. ej. de 15 % a 12 %). Para cambiarlo se
inserta una tarifa nueva con su fecha de vigencia, sin modificar código.
Las reservas guardan el porcentaje aplicado, así las facturas antiguas no cambian.
"""
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from models.base import Modelo, requerir

_CENTAVOS = Decimal("0.01")


def redondear(valor: Decimal) -> Decimal:
    """Redondeo comercial a 2 decimales (0.125 -> 0.13)."""
    return valor.quantize(_CENTAVOS, rounding=ROUND_HALF_UP)


@dataclass(frozen=True)
class DesgloseIva:
    subtotal: Decimal
    iva_porcentaje: Decimal
    iva_valor: Decimal
    total: Decimal


@dataclass(frozen=True)
class TarifaIva(Modelo):
    id: int | None
    porcentaje: Decimal
    vigente_desde: date
    vigente_hasta: date | None  # None = vigente hasta nuevo aviso

    def vigente_en(self, fecha: date) -> bool:
        return self.vigente_desde <= fecha and (self.vigente_hasta is None or fecha < self.vigente_hasta)

    def calcular(self, subtotal: Decimal) -> DesgloseIva:
        subtotal = redondear(subtotal)
        iva_valor = redondear(subtotal * self.porcentaje / 100)
        return DesgloseIva(
            subtotal=subtotal,
            iva_porcentaje=self.porcentaje,
            iva_valor=iva_valor,
            total=subtotal + iva_valor,
        )

    def _validar(self) -> None:
        requerir(0 <= self.porcentaje <= 100, "El porcentaje de IVA debe estar entre 0 y 100.")
        requerir(
            self.vigente_hasta is None or self.vigente_hasta > self.vigente_desde,
            "La fecha de fin de vigencia debe ser posterior a la de inicio.",
        )
