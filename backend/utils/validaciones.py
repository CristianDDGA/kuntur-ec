"""Validaciones de entrada compartidas por todos los servicios.

Una sola fuente de reglas: los servicios no repiten expresiones regulares ni mensajes.
Todas lanzan ValidationError (-> HTTP 400) con un mensaje en español.

Principios:
- Se valida con lista blanca (lo que SÍ se acepta), no con lista negra de caracteres peligrosos.
  Así emojis, símbolos, <script> o comillas SQL en un nombre se rechazan sin tener que preverlos.
- El SQL siempre va parametrizado; estas reglas protegen la calidad de los datos, no sustituyen eso.
"""
from __future__ import annotations

import math
import re
import unicodedata
from datetime import date, time
from decimal import Decimal, InvalidOperation
from typing import Any

from utils.excepciones import ValidationError
from utils.limites import CORREO as MAX_LARGO_CORREO
from utils.limites import MAX_ID, MAX_VERSION, PRECIO_MAXIMO  # noqa: F401 - se reexportan para los servicios

MAX_PROFUNDIDAD_JSON = 4

# Cc: control (NUL, \n, \t...), Cs: sustitutos rotos, Co: uso privado, Cn: sin asignar.
_CATEGORIAS_PROHIBIDAS = frozenset({"Cc", "Cs", "Co", "Cn"})
_APOSTROFES_Y_SIGNOS_DE_NOMBRE = frozenset(" '’-.")
_CORREO = re.compile(
    r"^[A-Za-z0-9._%+-]{1,64}@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}$"
)
_FECHA = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
_HORA = re.compile(r"^[0-9]{2}:[0-9]{2}$")


# ---------------------------------------------------------------- texto


def revisar_texto(valor: str, campo: str) -> None:
    """Rechaza caracteres de control (incluido NUL), que PostgreSQL no admite y no tienen uso legítimo."""
    if any(unicodedata.category(c) in _CATEGORIAS_PROHIBIDAS for c in valor):
        raise ValidationError(f"El campo '{campo}' contiene caracteres no permitidos.")


def revisar_json(valor: Any, campo: str = "cuerpo", nivel: int = 0) -> None:
    """Recorre todo el JSON recibido: texto sin caracteres de control, números finitos, poca profundidad."""
    if nivel > MAX_PROFUNDIDAD_JSON:
        raise ValidationError("La estructura del JSON es demasiado profunda.")
    if isinstance(valor, str):
        revisar_texto(valor, campo)
    elif isinstance(valor, float) and not math.isfinite(valor):
        raise ValidationError(f"El campo '{campo}' debe ser un número finito.")
    elif isinstance(valor, dict):
        for clave, contenido in valor.items():
            revisar_texto(str(clave), campo)
            revisar_json(contenido, str(clave), nivel + 1)
    elif isinstance(valor, list):
        for contenido in valor:
            revisar_json(contenido, campo, nivel + 1)


def texto_obligatorio(datos: dict, campo: str, maximo: int, normalizar: bool = True) -> str:
    """Texto no vacío, sin caracteres de control y de largo acotado.

    `normalizar` colapsa espacios repetidos y unifica tildes (NFC). No se usa en contraseñas.
    """
    valor = datos.get(campo)
    if not isinstance(valor, str) or not valor.strip():
        raise ValidationError(f"El campo '{campo}' es obligatorio.")
    revisar_texto(valor, campo)
    if normalizar:
        valor = " ".join(unicodedata.normalize("NFC", valor).split())
    if len(valor) > maximo:
        raise ValidationError(f"El campo '{campo}' no puede superar {maximo} caracteres.")
    return valor


def nombre_propio(datos: dict, campo: str, maximo: int, minimo_letras: int = 2) -> str:
    """Nombres de personas y ciudades: solo letras (con tildes), espacios, apóstrofes, puntos y guiones."""
    valor = texto_obligatorio(datos, campo, maximo)
    letras = 0
    for caracter in valor:
        if caracter.isalpha():
            letras += 1
        elif caracter in _APOSTROFES_Y_SIGNOS_DE_NOMBRE or unicodedata.category(caracter).startswith("M"):
            continue  # "M": tildes escritas como carácter combinado
        else:
            raise ValidationError(
                f"El campo '{campo}' solo admite letras, espacios, apóstrofes, puntos y guiones."
            )
    if letras < minimo_letras:
        raise ValidationError(f"El campo '{campo}' debe tener al menos {minimo_letras} letras.")
    return valor


def es_correo(valor: str) -> bool:
    if len(valor) > MAX_LARGO_CORREO or ".." in valor or not _CORREO.match(valor):
        return False
    local = valor.split("@", 1)[0]
    return not (local.startswith(".") or local.endswith("."))


def correo(datos: dict, campo: str = "correo") -> str:
    """Correo en minúsculas, solo ASCII (sin emojis, espacios ni símbolos raros)."""
    valor = texto_obligatorio(datos, campo, MAX_LARGO_CORREO).lower()
    if not es_correo(valor):
        raise ValidationError("El correo no es válido.")
    return valor


# ---------------------------------------------------------------- números


def entero(datos: dict, campo: str, minimo: int, maximo: int) -> int:
    """Entero en un rango. Rechaza texto, decimales, booleanos y valores gigantes."""
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, int) or not minimo <= valor <= maximo:
        raise ValidationError(
            f"El campo '{campo}' es obligatorio y debe ser un número entero entre {minimo} y {maximo}."
        )
    return valor


def identificador(datos: dict, campo: str) -> int:
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, int) or not 1 <= valor <= MAX_ID:
        raise ValidationError(f"El campo '{campo}' es obligatorio y debe ser un identificador numérico válido.")
    return valor


def precio(datos: dict, campo: str = "precio", maximo: Decimal = Decimal(PRECIO_MAXIMO)) -> Decimal:
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, (int, float, str)):
        raise ValidationError(f"El campo '{campo}' es obligatorio y debe ser numérico.")
    try:
        monto = Decimal(str(valor).strip())
    except InvalidOperation:
        raise ValidationError(f"El campo '{campo}' debe ser numérico.") from None
    if not monto.is_finite():
        raise ValidationError(f"El campo '{campo}' debe ser numérico.")
    if monto.as_tuple().exponent < -2:  # type: ignore[operator]
        raise ValidationError("El precio admite como máximo 2 decimales.")
    if monto <= 0:
        raise ValidationError("El precio debe ser mayor a 0.")
    if monto > maximo:
        raise ValidationError(f"El precio no puede superar {maximo}.")
    return monto


def porcentaje(datos: dict, campo: str = "porcentaje") -> Decimal:
    """Porcentaje de 0 a 100 con hasta 2 decimales (columna NUMERIC(5,2))."""
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, (int, float, str)):
        raise ValidationError(f"El campo '{campo}' es obligatorio y debe ser numérico.")
    try:
        monto = Decimal(str(valor).strip())
    except InvalidOperation:
        raise ValidationError(f"El campo '{campo}' debe ser numérico.") from None
    if not monto.is_finite():
        raise ValidationError(f"El campo '{campo}' debe ser numérico.")
    if monto.as_tuple().exponent < -2:  # type: ignore[operator]
        raise ValidationError(f"El campo '{campo}' admite como máximo 2 decimales.")
    if not 0 <= monto <= 100:
        raise ValidationError(f"El campo '{campo}' debe estar entre 0 y 100.")
    return monto


# ---------------------------------------------------------------- fechas y horas


def fecha_iso(valor: Any, campo: str = "fecha") -> date:
    """AAAA-MM-DD estricto (Python acepta además formatos como 20261230 o 2026-W01-1)."""
    if isinstance(valor, str) and _FECHA.match(valor.strip()):
        try:
            return date.fromisoformat(valor.strip())
        except ValueError:
            pass
    raise ValidationError(f"El campo '{campo}' debe tener el formato AAAA-MM-DD.")


def hora_hhmm(valor: Any, campo: str) -> time:
    if isinstance(valor, str) and _HORA.match(valor.strip()):
        horas, minutos = valor.strip().split(":")
        try:
            return time(int(horas), int(minutos))
        except ValueError:
            pass
    raise ValidationError(f"El campo '{campo}' debe tener el formato HH:MM.")
