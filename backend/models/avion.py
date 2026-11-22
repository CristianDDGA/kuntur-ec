"""Tabla `aviones`."""
from dataclasses import dataclass

from models.base import Modelo, requerir, texto_presente
from utils.asientos import COLUMNAS
from utils.limites import FILAS_MAXIMAS


@dataclass(frozen=True)
class Avion(Modelo):
    id: int | None
    matricula: str
    modelo: str
    filas: int

    @property
    def capacidad(self) -> int:
        """Cada fila tiene un asiento por columna (A-D): 30 filas = 120 asientos."""
        return self.filas * len(COLUMNAS)

    def to_dict(self) -> dict:
        return super().to_dict() | {"capacidad": self.capacidad}

    def _validar(self) -> None:
        requerir(texto_presente(self.matricula), "La matrícula es obligatoria.")
        requerir(texto_presente(self.modelo), "El modelo es obligatorio.")
        requerir(1 <= self.filas <= FILAS_MAXIMAS, f"Las filas deben estar entre 1 y {FILAS_MAXIMAS}.")
