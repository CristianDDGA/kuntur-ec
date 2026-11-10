"""Tabla `tokens`: JWT emitidos, para poder revocarlos al cerrar sesión."""
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import ClassVar

from models.base import Modelo, requerir, texto_presente


class EstadoToken(StrEnum):
    ACTIVO = "activo"
    REVOCADO = "revocado"


@dataclass(frozen=True)
class Token(Modelo):
    id: int | None
    usuario_id: int
    token: str
    expiracion: datetime
    estado: EstadoToken

    # El JWT no se expone en listados ni respuestas.
    CAMPOS_PRIVADOS: ClassVar[frozenset[str]] = frozenset({"token"})

    def es_valido(self, ahora: datetime) -> bool:
        return self.estado is EstadoToken.ACTIVO and ahora < self.expiracion

    def _validar(self) -> None:
        requerir(texto_presente(self.token), "El token es obligatorio.")
        requerir(isinstance(self.estado, EstadoToken), "El estado del token no es válido.")
