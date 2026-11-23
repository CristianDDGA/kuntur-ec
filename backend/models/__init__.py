"""Modelos: dataclasses que representan las tablas (from_row / to_dict). Sin SQL ni HTTP."""
from models.avion import Avion
from models.reserva import EstadoReserva, Reserva
from models.tarifa_iva import DesgloseIva, TarifaIva
from models.token import EstadoToken, Token
from models.usuario import Rol, Usuario
from models.vuelo import EstadoVuelo, Vuelo

__all__ = [
    "Avion",
    "DesgloseIva",
    "EstadoReserva",
    "EstadoToken",
    "EstadoVuelo",
    "Reserva",
    "Rol",
    "TarifaIva",
    "Token",
    "Usuario",
    "Vuelo",
]
