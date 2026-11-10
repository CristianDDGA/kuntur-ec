"""Tabla `vuelos`."""
from dataclasses import dataclass
from datetime import date, time
from decimal import Decimal

from models.base import Modelo, requerir, texto_presente


@dataclass(frozen=True)
class Vuelo(Modelo):
    id: int | None
    codigo: str
    origen: str
    destino: str
    fecha: date
    hora_salida: time
    hora_llegada: time
    precio: Decimal
    capacidad: int
    asientos_disponibles: int

    def tiene_asientos(self, cantidad: int) -> bool:
        return 0 < cantidad <= self.asientos_disponibles

    def subtotal(self, cantidad: int) -> Decimal:
        """Precio de `cantidad` asientos, antes de impuestos."""
        return self.precio * cantidad

    def _validar(self) -> None:
        requerir(texto_presente(self.codigo), "El código del vuelo es obligatorio.")
        requerir(texto_presente(self.origen), "El origen es obligatorio.")
        requerir(texto_presente(self.destino), "El destino es obligatorio.")
        requerir(
            self.origen.strip().lower() != self.destino.strip().lower(),
            "El origen y el destino deben ser diferentes.",
        )
        requerir(self.precio > 0, "El precio debe ser mayor a 0.")
        requerir(self.capacidad > 0, "La capacidad debe ser mayor a 0.")
        requerir(
            0 <= self.asientos_disponibles <= self.capacidad,
            "Los asientos disponibles deben estar entre 0 y la capacidad del vuelo.",
        )
