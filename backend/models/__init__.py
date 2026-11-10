"""Modelos: dataclasses que representan las tablas (from_row / to_dict). Sin SQL ni HTTP."""
from models.reserva import EstadoReserva, Reserva
from models.tarifa_iva import DesgloseIva, TarifaIva
from models.token import EstadoToken, Token
from models.usuario import Rol, Usuario
from models.vuelo import Vuelo

__all__ = [
    "DesgloseIva",
    "EstadoReserva",
    "EstadoToken",
    "Reserva",
    "Rol",
    "TarifaIva",
    "Token",
    "Usuario",
    "Vuelo",
]
