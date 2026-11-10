"""Comportamiento común de todos los modelos (sin duplicar código en cada uno)."""
from __future__ import annotations

from collections.abc import Mapping
from dataclasses import fields
from decimal import Decimal
from enum import Enum
from typing import Any, ClassVar, Self, get_args, get_type_hints

from utils.excepciones import ValidationError


def _tipo_base(anotacion: Any) -> Any:
    """`Rol | None` -> `Rol`; tipos simples se devuelven igual."""
    candidatos = [t for t in get_args(anotacion) if t is not type(None)]
    return candidatos[0] if candidatos else anotacion


def _convertir(valor: Any, tipo: Any) -> Any:
    if valor is None:
        return None
    if isinstance(tipo, type) and issubclass(tipo, Enum) and not isinstance(valor, tipo):
        return tipo(valor)
    if tipo is Decimal and not isinstance(valor, Decimal):
        return Decimal(str(valor))
    return valor


class Modelo:
    """Base de los dataclasses del sistema.

    - `from_row`: crea el modelo desde una fila de la BD (dict), convirtiendo Enum y Decimal.
    - `to_dict`: datos listos para la vista (JSON/XML), sin los campos privados.
    - `_validar`: cada modelo define sus reglas; se ejecuta al construirlo.
    """

    CAMPOS_PRIVADOS: ClassVar[frozenset[str]] = frozenset()

    def __post_init__(self) -> None:
        self._validar()

    def _validar(self) -> None:
        """Reglas del modelo. Lanza ValidationError si los datos no son válidos."""

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> Self:
        tipos = get_type_hints(cls)
        return cls(**{
            f.name: _convertir(row[f.name], _tipo_base(tipos[f.name]))
            for f in fields(cls)  # type: ignore[arg-type]
            if f.name in row
        })

    def to_dict(self) -> dict[str, Any]:
        return {
            f.name: getattr(self, f.name)
            for f in fields(self)  # type: ignore[arg-type]
            if f.name not in self.CAMPOS_PRIVADOS
        }


def requerir(condicion: bool, mensaje: str) -> None:
    """Atajo para expresar una regla de validación en una línea."""
    if not condicion:
        raise ValidationError(mensaje)


def texto_presente(valor: str | None) -> bool:
    return bool(valor and valor.strip())
