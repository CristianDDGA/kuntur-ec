"""Paginación compartida por las listas (vuelos, reservas)."""
from __future__ import annotations

from utils.excepciones import ValidationError

POR_PAGINA_DEFECTO = 10
POR_PAGINA_MAXIMO = 50
MAX_PAGINA = 100_000


def numero_consulta(valor: str | None, campo: str, defecto: int, maximo: int) -> int:
    """Número entero positivo de la URL (`?pagina=2`). Vacío = valor por defecto; basura = 400."""
    if valor is None or not str(valor).strip():
        return defecto
    texto = str(valor).strip()
    if not texto.isascii() or not texto.isdigit() or not 1 <= int(texto) <= maximo:
        raise ValidationError(f"El parámetro '{campo}' debe ser un número entero entre 1 y {maximo}.")
    return int(texto)


def leer_pagina(pagina: str | None, por_pagina: str | None) -> tuple[int, int]:
    """(pagina, por_pagina) ya validados."""
    return (
        numero_consulta(pagina, "pagina", 1, MAX_PAGINA),
        numero_consulta(por_pagina, "por_pagina", POR_PAGINA_DEFECTO, POR_PAGINA_MAXIMO),
    )


def total_paginas(total: int, por_pagina: int) -> int:
    """Páginas necesarias (división hacia arriba); mínimo 1 aunque no haya resultados."""
    return max(1, -(-total // por_pagina))
