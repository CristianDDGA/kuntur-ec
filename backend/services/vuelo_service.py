"""Servicio Vuelos: búsqueda, detalle y creación (solo administrador)."""
from __future__ import annotations

from collections.abc import Callable
from datetime import date, datetime, time
from decimal import Decimal, InvalidOperation
from typing import Any

from psycopg.errors import UniqueViolation

from database import Database
from models import Vuelo
from utils.excepciones import ConflictError, NotFoundError, ValidationError

_COLUMNAS = (
    "id, codigo, origen, destino, fecha, hora_salida, hora_llegada, "
    "precio, capacidad, asientos_disponibles, version"
)
MAX_LARGO_CODIGO = 10
MAX_LARGO_CIUDAD = 80
MAX_CAPACIDAD = 900


# ---------------------------------------------------------------- lectura de datos


def _texto(datos: dict, campo: str, maximo: int) -> str:
    valor = datos.get(campo)
    if not isinstance(valor, str) or not valor.strip():
        raise ValidationError(f"El campo '{campo}' es obligatorio.")
    valor = " ".join(valor.split())
    if len(valor) > maximo:
        raise ValidationError(f"El campo '{campo}' no puede superar {maximo} caracteres.")
    return valor


def leer_fecha(valor: Any, campo: str = "fecha") -> date:
    try:
        return date.fromisoformat(str(valor).strip())
    except ValueError:
        raise ValidationError(f"El campo '{campo}' debe tener el formato AAAA-MM-DD.") from None


def _hora(datos: dict, campo: str) -> time:
    try:
        return datetime.strptime(str(datos.get(campo, "")).strip(), "%H:%M").time()
    except ValueError:
        raise ValidationError(f"El campo '{campo}' debe tener el formato HH:MM.") from None


def _precio(datos: dict) -> Decimal:
    valor = datos.get("precio")
    if isinstance(valor, bool) or not isinstance(valor, (int, float, str)):
        raise ValidationError("El campo 'precio' es obligatorio y debe ser numérico.")
    try:
        precio = Decimal(str(valor).strip())
    except InvalidOperation:
        raise ValidationError("El campo 'precio' debe ser numérico.") from None
    if not precio.is_finite() or precio.as_tuple().exponent < -2:  # type: ignore[operator]
        raise ValidationError("El precio admite como máximo 2 decimales.")
    return precio


def _entero(datos: dict, campo: str) -> int:
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, int):
        raise ValidationError(f"El campo '{campo}' debe ser un número entero.")
    return valor


# ---------------------------------------------------------------- servicio


class VueloService:
    def __init__(self, db: Database, hoy: Callable[[], date] = date.today):
        self._db = db
        self._hoy = hoy  # inyectable para las pruebas

    def buscar(self, origen: str | None = None, destino: str | None = None, fecha: str | None = None) -> list[Vuelo]:
        """Vuelos desde hoy en adelante, filtrados por origen, destino y/o fecha (sin distinguir mayúsculas)."""
        condiciones, params = ["fecha >= %s"], [self._hoy()]
        if origen and origen.strip():
            condiciones.append("lower(origen) = lower(%s)")
            params.append(" ".join(origen.split()))
        if destino and destino.strip():
            condiciones.append("lower(destino) = lower(%s)")
            params.append(" ".join(destino.split()))
        if fecha and fecha.strip():
            condiciones.append("fecha = %s")
            params.append(leer_fecha(fecha))

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
        capacidad = _entero(datos, "capacidad")
        if capacidad > MAX_CAPACIDAD:
            raise ValidationError(f"La capacidad no puede superar {MAX_CAPACIDAD} asientos.")
        vuelo = Vuelo(  # el modelo valida origen ≠ destino, precio > 0, capacidad > 0
            id=None,
            codigo=_texto(datos, "codigo", MAX_LARGO_CODIGO).upper().replace(" ", ""),
            origen=_texto(datos, "origen", MAX_LARGO_CIUDAD),
            destino=_texto(datos, "destino", MAX_LARGO_CIUDAD),
            fecha=leer_fecha(datos.get("fecha")),
            hora_salida=_hora(datos, "hora_salida"),
            hora_llegada=_hora(datos, "hora_llegada"),
            precio=_precio(datos),
            capacidad=capacidad,
            asientos_disponibles=capacidad,  # un vuelo nuevo empieza con todos sus asientos libres
        )
        if vuelo.fecha < self._hoy():
            raise ValidationError("No se puede crear un vuelo con fecha pasada.")
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
