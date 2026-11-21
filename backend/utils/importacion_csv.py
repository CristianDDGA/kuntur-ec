"""Lectura de archivos CSV de importación (por ahora, aviones).

Formato del CSV de aviones (con encabezado; separador coma o punto y coma, como lo exporta Excel):

    matricula;modelo;filas
    HC-ABC;Airbus A320;30
    HC-XYZ;ATR 72;18

Todo se valida antes de tocar la base: cada fila inválida se reporta con su número de línea, para que
quien sube el archivo pueda corregirlo de una vez en lugar de descubrir los errores de a uno.
"""
from __future__ import annotations

import csv
import io
import re
from dataclasses import dataclass, field

from utils.excepciones import ValidationError
from utils.limites import BYTES_CSV, FILAS_CSV, FILAS_MAXIMAS, MATRICULA, MODELO_AVION

_MATRICULA = re.compile(rf"^[A-Z0-9-]{{3,{MATRICULA}}}$")
_ENCABEZADO = ("matricula", "modelo", "filas")
_SEPARADORES = ",;"


@dataclass(frozen=True)
class FilaAvion:
    linea: int
    matricula: str
    modelo: str
    filas: int


@dataclass(frozen=True)
class ResultadoCsv:
    """Filas válidas y errores por línea de un archivo."""

    validas: list[FilaAvion] = field(default_factory=list)
    errores: list[dict] = field(default_factory=list)
    total_filas: int = 0


def _texto(contenido: bytes) -> str:
    if len(contenido) > BYTES_CSV:
        raise ValidationError(f"El archivo supera el máximo de {BYTES_CSV // 1024} KB.")
    if not contenido.strip():
        raise ValidationError("El archivo está vacío.")
    try:
        return contenido.decode("utf-8-sig")  # utf-8 con o sin BOM (Excel lo agrega)
    except UnicodeDecodeError:
        raise ValidationError("El archivo debe estar codificado en UTF-8.") from None


def _quitar_acentos(valor: str) -> str:
    return valor.strip().lower().translate(str.maketrans("áéíóúñ", "aeioun"))


def leer_aviones(contenido: bytes) -> ResultadoCsv:
    """Convierte el CSV en filas válidas y errores. Lanza ValidationError solo si el archivo entero no sirve."""
    texto = _texto(contenido)
    primera = texto.splitlines()[0]
    separador = max(_SEPARADORES, key=primera.count)
    if primera.count(separador) == 0:
        raise ValidationError("No se encontró el encabezado: use 'matricula;modelo;filas'.")
    lector = csv.reader(io.StringIO(texto), delimiter=separador)

    encabezado = tuple(_quitar_acentos(c) for c in next(lector))
    if encabezado != _ENCABEZADO:
        raise ValidationError(
            f"El encabezado debe ser exactamente: {';'.join(_ENCABEZADO)} (se encontró: {';'.join(encabezado)[:80]})."
        )

    validas: list[FilaAvion] = []
    errores: list[dict] = []
    vistas: dict[str, int] = {}
    total = 0
    for linea, campos in enumerate(lector, start=2):
        if not any(c.strip() for c in campos):
            continue  # línea en blanco
        total += 1
        if total > FILAS_CSV:
            raise ValidationError(f"El archivo supera el máximo de {FILAS_CSV} aviones.")
        problemas = _revisar(campos)
        matricula = campos[0].strip().upper() if campos else ""
        if not problemas and matricula in vistas:
            problemas = [f"La matrícula {matricula} está repetida (ya aparece en la línea {vistas[matricula]})."]
        if problemas:
            errores.extend({"linea": linea, "mensaje": m} for m in problemas)
            continue
        vistas[matricula] = linea
        validas.append(FilaAvion(linea, matricula, campos[1].strip(), int(campos[2].strip())))
    return ResultadoCsv(validas, errores, total)


def _revisar(campos: list[str]) -> list[str]:
    if len(campos) != len(_ENCABEZADO):
        return [f"Debe tener {len(_ENCABEZADO)} columnas (matrícula, modelo, filas) y tiene {len(campos)}."]
    matricula, modelo, filas = (c.strip() for c in campos)
    problemas: list[str] = []
    if not _MATRICULA.match(matricula.upper()):
        problemas.append(f"Matrícula inválida: use de 3 a {MATRICULA} letras, números o guiones (por ejemplo HC-ABC).")
    if not modelo or len(modelo) > MODELO_AVION:
        problemas.append(f"El modelo es obligatorio y admite hasta {MODELO_AVION} caracteres.")
    if not re.fullmatch(r"[0-9]{1,3}", filas) or not 1 <= int(filas) <= FILAS_MAXIMAS:
        problemas.append(f"Las filas deben ser un entero entre 1 y {FILAS_MAXIMAS}.")
    return problemas
