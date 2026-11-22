"""Distribución de asientos de un vuelo.

Los asientos se numeran por fila y columna ("1A", "1B", "1C", "1D", "2A"...): 4 columnas, de modo que
un vuelo de 200 asientos tiene 50 filas. Los asientos que existen se deducen de la capacidad del vuelo,
no se guardan; en la base solo se guardan los que ya tiene alguna reserva (`reserva_asientos`).
"""
from __future__ import annotations

import re
from collections.abc import Iterable

from utils.excepciones import ValidationError
from utils.limites import ASIENTO, ASIENTOS_POR_RESERVA

COLUMNAS = "ABCD"
_FORMATO = re.compile(rf"^[1-9][0-9]{{0,2}}[{COLUMNAS}]$")


def etiqueta(posicion: int) -> str:
    """Posición 0, 1, 2... -> "1A", "1B", "1C", "1D", "2A"..."""
    fila, columna = divmod(posicion, len(COLUMNAS))
    return f"{fila + 1}{COLUMNAS[columna]}"


def etiquetas(capacidad: int) -> list[str]:
    """Todos los asientos de un vuelo, en orden."""
    return [etiqueta(i) for i in range(capacidad)]


def orden(asiento: str) -> tuple[int, str]:
    """Clave para ordenar asientos: por fila y luego por columna ("2A" antes que "10A")."""
    return int(asiento[:-1]), asiento[-1]


def lista_de_asientos(valor: object, campo: str = "asientos") -> list[str]:
    """Valida la lista que envía el cliente: 1 a 10 asientos con formato válido, en mayúsculas y sin repetir."""
    if not isinstance(valor, list) or not valor:
        raise ValidationError(f"El campo '{campo}' debe ser una lista con al menos un asiento, por ejemplo [\"1A\"].")
    if len(valor) > ASIENTOS_POR_RESERVA:
        raise ValidationError(f"Una reserva admite como máximo {ASIENTOS_POR_RESERVA} asientos.")
    limpios: list[str] = []
    for item in valor:
        if not isinstance(item, str) or len(item.strip()) > ASIENTO:
            raise ValidationError(f"Cada elemento de '{campo}' debe ser un asiento como \"1A\" o \"12D\".")
        codigo = item.strip().upper()
        if not _FORMATO.match(codigo):
            raise ValidationError(f"El asiento '{item.strip()[:ASIENTO]}' no es válido: use fila y letra A-D, por ejemplo 12C.")
        if codigo in limpios:
            raise ValidationError(f"El asiento {codigo} está repetido.")
        limpios.append(codigo)
    return sorted(limpios, key=orden)


def validar_existen(asientos: Iterable[str], capacidad: int) -> None:
    """Todos deben existir en un vuelo de esa capacidad (un vuelo de 6 asientos no tiene el 9D)."""
    existentes = set(etiquetas(capacidad))
    for a in asientos:
        if a not in existentes:
            raise ValidationError(f"El asiento {a} no existe en este vuelo.")
