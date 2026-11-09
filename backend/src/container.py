"""Composition root (inyección de dependencias).

Único lugar donde se conectan las implementaciones concretas (infraestructura)
con los casos de uso (aplicación). El resto del código depende solo de
abstracciones (principio de Inversión de Dependencias).

Se irá completando por secciones:
    - Usuarios:  UsuarioRepository + PasswordHasher -> RegistrarUsuario
    - Auth:      TokenProvider -> IniciarSesion / CerrarSesion
    - Vuelos:    VueloRepository -> BuscarVuelos / ObtenerVuelo / CrearVuelo
    - Reservas:  ReservaRepository + UnitOfWork -> CrearReserva / ...
"""
from __future__ import annotations

from dataclasses import dataclass

from src.infrastructure.config.settings import Settings


@dataclass
class Container:
    settings: Settings

    @classmethod
    def build(cls, settings: Settings) -> "Container":
        return cls(settings=settings)
