"""Servicio Vuelos: búsqueda, detalle y creación (solo administrador)."""
from __future__ import annotations

import re
from collections.abc import Callable
from datetime import date, timedelta

from psycopg.errors import UniqueViolation

from database import Database
from models import Vuelo
from utils.excepciones import ConflictError, NotFoundError, ValidationError
from utils.limites import CAPACIDAD_MAXIMA as MAX_CAPACIDAD
from utils.limites import CIUDAD as MAX_LARGO_CIUDAD
from utils.limites import CODIGO_VUELO as MAX_LARGO_CODIGO
from utils.validaciones import (
    entero,
    fecha_iso,
    hora_hhmm,
    nombre_propio,
    precio,
    revisar_texto,
    texto_obligatorio,
)

_COLUMNAS = (
    "id, codigo, origen, destino, fecha, hora_salida, hora_llegada, "
    "precio, capacidad, asientos_disponibles, version"
)
MAX_DIAS_ADELANTE = 730  # no se programan vuelos a más de 2 años
_CODIGO = re.compile(rf"^[A-Z0-9-]{{2,{MAX_LARGO_CODIGO}}}$")


def _filtro(valor: str | None, campo: str) -> str | None:
    """Filtro de búsqueda opcional: sin caracteres de control y de largo acotado."""
    if not valor or not valor.strip():
        return None
    revisar_texto(valor, campo)
    limpio = " ".join(valor.split())
    if len(limpio) > MAX_LARGO_CIUDAD:
        raise ValidationError(f"El filtro '{campo}' no puede superar {MAX_LARGO_CIUDAD} caracteres.")
    return limpio


# ---------------------------------------------------------------- servicio


class VueloService:
    def __init__(self, db: Database, hoy: Callable[[], date] = date.today):
        self._db = db
        self._hoy = hoy  # inyectable para las pruebas

    def buscar(self, origen: str | None = None, destino: str | None = None, fecha: str | None = None) -> list[Vuelo]:
        """Vuelos desde hoy en adelante, filtrados por origen, destino y/o fecha (sin distinguir mayúsculas)."""
        condiciones, params = ["fecha >= %s"], [self._hoy()]
        if (origen := _filtro(origen, "origen")):
            condiciones.append("lower(origen) = lower(%s)")
            params.append(origen)
        if (destino := _filtro(destino, "destino")):
            condiciones.append("lower(destino) = lower(%s)")
            params.append(destino)
        if (fecha := _filtro(fecha, "fecha")):
            condiciones.append("fecha = %s")
            params.append(fecha_iso(fecha))

        with self._db.transaccion() as cur:
            cur.execute(
                f"SELECT {_COLUMNAS} FROM vuelos WHERE {' AND '.join(condiciones)} "
                "ORDER BY fecha, hora_salida, codigo",
                tuple(params),
            )
            return [Vuelo.from_row(fila) for fila in cur.fetchall()]

    def obtener(self, vuelo_id: int) -> Vuelo:
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM vuelos WHERE id = %s", (vuelo_id,))
            fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El vuelo solicitado no existe.")
        return Vuelo.from_row(fila)

    def crear(self, datos: dict) -> Vuelo:
        capacidad = entero(datos, "capacidad", 1, MAX_CAPACIDAD)
        codigo = texto_obligatorio(datos, "codigo", MAX_LARGO_CODIGO).upper().replace(" ", "")
        if not _CODIGO.match(codigo):
            raise ValidationError(f"El campo 'codigo' solo admite letras, números y guiones (de 2 a {MAX_LARGO_CODIGO} caracteres).")
        vuelo = Vuelo(  # el modelo valida además origen ≠ destino y asientos entre 0 y la capacidad
            id=None,
            codigo=codigo,
            origen=nombre_propio(datos, "origen", MAX_LARGO_CIUDAD),
            destino=nombre_propio(datos, "destino", MAX_LARGO_CIUDAD),
            fecha=fecha_iso(datos.get("fecha")),
            hora_salida=hora_hhmm(datos.get("hora_salida"), "hora_salida"),
            hora_llegada=hora_hhmm(datos.get("hora_llegada"), "hora_llegada"),
            precio=precio(datos),
            capacidad=capacidad,
            asientos_disponibles=capacidad,  # un vuelo nuevo empieza con todos sus asientos libres
        )
        if vuelo.fecha < self._hoy():
            raise ValidationError("No se puede crear un vuelo con fecha pasada.")
        if vuelo.fecha > self._hoy() + timedelta(days=MAX_DIAS_ADELANTE):
            raise ValidationError("La fecha del vuelo no puede superar los 2 años desde hoy.")
        if vuelo.hora_llegada == vuelo.hora_salida:
            raise ValidationError("La hora de llegada debe ser distinta a la de salida.")

        try:
            with self._db.transaccion() as cur:
                cur.execute(
                    "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, "
                    "precio, capacidad, asientos_disponibles) "
                    f"VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING {_COLUMNAS}",
                    (
                        vuelo.codigo, vuelo.origen, vuelo.destino, vuelo.fecha, vuelo.hora_salida,
                        vuelo.hora_llegada, vuelo.precio, vuelo.capacidad, vuelo.asientos_disponibles,
                    ),
                )
                return Vuelo.from_row(cur.fetchone())
        except UniqueViolation:
            raise ConflictError(f"Ya existe un vuelo con el código {vuelo.codigo}.") from None
