"""Servicio Vuelos: búsqueda, detalle y creación (solo administrador)."""
from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from psycopg.errors import UniqueViolation

from database import Database
from models import Vuelo
from utils.asientos import COLUMNAS
from utils.excepciones import ConflictError, NotFoundError, ValidationError
from utils.paginacion import leer_pagina, total_paginas
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
PREFIJO_CODIGO = "KT"
PRIMER_NUMERO = 101  # el primer vuelo generado es KT101
INTENTOS_CODIGO = 5  # reintentos si dos administradores crean vuelos a la vez
# Siguiente código libre: KT + (mayor número existente + 1). Se evalúa dentro del mismo INSERT.
_SQL_CODIGO_NUEVO = (
    f"(SELECT '{PREFIJO_CODIGO}' || COALESCE(MAX(substring(codigo FROM '^{PREFIJO_CODIGO}([0-9]+)$')::int) + 1, "
    f"{PRIMER_NUMERO}) FROM vuelos)"
)


def _filtro(valor: str | None, campo: str) -> str | None:
    """Filtro de búsqueda opcional: sin caracteres de control y de largo acotado."""
    if not valor or not valor.strip():
        return None
    revisar_texto(valor, campo)
    limpio = " ".join(valor.split())
    if len(limpio) > MAX_LARGO_CIUDAD:
        raise ValidationError(f"El filtro '{campo}' no puede superar {MAX_LARGO_CIUDAD} caracteres.")
    return limpio


@dataclass(frozen=True)
class PaginaVuelos:
    """Una página de resultados y los datos para pedir las demás."""

    vuelos: list[Vuelo]
    total: int
    pagina: int
    por_pagina: int

    @property
    def total_paginas(self) -> int:
        return total_paginas(self.total, self.por_pagina)

    def to_dict(self) -> dict:
        return {
            "total": self.total,
            "pagina": self.pagina,
            "por_pagina": self.por_pagina,
            "total_paginas": self.total_paginas,
            "vuelos": [v.to_dict() for v in self.vuelos],
        }


# ---------------------------------------------------------------- servicio


class VueloService:
    def __init__(
        self,
        db: Database,
        hoy: Callable[[], date] | None = None,
        ahora: Callable[[], datetime] = datetime.now,
    ):
        self._db = db
        self._ahora = ahora  # inyectables para las pruebas
        self._hoy = hoy or (lambda: self._ahora().date())

    def _hora_actual(self):
        return self._ahora().time().replace(second=0, microsecond=0)

    def buscar(
        self,
        origen: str | None = None,
        destino: str | None = None,
        fecha: str | None = None,
        pagina: str | None = None,
        por_pagina: str | None = None,
    ) -> PaginaVuelos:
        """Vuelos que aún no parten, filtrados por origen, destino y/o fecha (sin distinguir mayúsculas), paginados."""
        numero, tamano = leer_pagina(pagina, por_pagina)
        condiciones = ["(fecha > %s OR (fecha = %s AND hora_salida > %s))"]
        params: list = [self._hoy(), self._hoy(), self._hora_actual()]
        if (origen := _filtro(origen, "origen")):
            condiciones.append("lower(origen) = lower(%s)")
            params.append(origen)
        if (destino := _filtro(destino, "destino")):
            condiciones.append("lower(destino) = lower(%s)")
            params.append(destino)
        if (fecha := _filtro(fecha, "fecha")):
            condiciones.append("fecha = %s")
            params.append(fecha_iso(fecha))

        donde = " AND ".join(condiciones)
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT count(*) AS total FROM vuelos WHERE {donde}", tuple(params))
            total = cur.fetchone()["total"]
            cur.execute(
                f"SELECT {_COLUMNAS} FROM vuelos WHERE {donde} ORDER BY fecha, hora_salida, codigo LIMIT %s OFFSET %s",
                (*params, tamano, (numero - 1) * tamano),
            )
            return PaginaVuelos([Vuelo.from_row(f) for f in cur.fetchall()], total, numero, tamano)

    def asientos(self, vuelo_id: int) -> dict:
        """Mapa de asientos: los que existen (por la capacidad) y cuáles ya están ocupados."""
        with self._db.transaccion() as cur:
            cur.execute("SELECT capacidad FROM vuelos WHERE id = %s", (vuelo_id,))
            fila = cur.fetchone()
            if fila is None:
                raise NotFoundError("El vuelo solicitado no existe.")
            cur.execute(
                "SELECT coalesce(array_agg(asiento ORDER BY length(asiento), asiento), ARRAY[]::varchar[]) AS ocupados "
                "FROM reserva_asientos WHERE vuelo_id = %s AND activo",
                (vuelo_id,),
            )
            ocupados = cur.fetchone()["ocupados"]
        return {
            "vuelo_id": vuelo_id,
            "capacidad": fila["capacidad"],
            "columnas": list(COLUMNAS),
            "ocupados": list(ocupados),
        }

    def obtener(self, vuelo_id: int) -> Vuelo:
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM vuelos WHERE id = %s", (vuelo_id,))
            fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El vuelo solicitado no existe.")
        return Vuelo.from_row(fila)

    def crear(self, datos: dict) -> Vuelo:
        """Crea un vuelo. Si `datos` trae `codigo` se respeta; si no, el sistema genera el siguiente (KT101, KT102...)."""
        capacidad = entero(datos, "capacidad", 1, MAX_CAPACIDAD)
        generar = datos.get("codigo") in (None, "")
        codigo = None if generar else texto_obligatorio(datos, "codigo", MAX_LARGO_CODIGO).upper().replace(" ", "")
        if codigo is not None and not _CODIGO.match(codigo):
            raise ValidationError(f"El campo 'codigo' solo admite letras, números y guiones (de 2 a {MAX_LARGO_CODIGO} caracteres).")
        vuelo = Vuelo(  # el modelo valida además origen ≠ destino y asientos entre 0 y la capacidad
            id=None,
            codigo=codigo or PREFIJO_CODIGO,  # provisional: el definitivo lo asigna la base al insertar
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
        if vuelo.fecha == self._hoy() and vuelo.hora_salida <= self._hora_actual():
            raise ValidationError(
                f"La hora de salida ya pasó: para hoy elija una hora posterior a las {self._hora_actual():%H:%M}."
            )
        if vuelo.fecha > self._hoy() + timedelta(days=MAX_DIAS_ADELANTE):
            raise ValidationError("La fecha del vuelo no puede superar los 2 años desde hoy.")
        if vuelo.hora_llegada == vuelo.hora_salida:
            raise ValidationError("La hora de llegada debe ser distinta a la de salida.")

        for intento in range(INTENTOS_CODIGO if generar else 1):
            try:
                with self._db.transaccion() as cur:
                    cur.execute(
                        "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, "
                        "precio, capacidad, asientos_disponibles) "
                        f"VALUES ({_SQL_CODIGO_NUEVO if generar else '%s'}, %s, %s, %s, %s, %s, %s, %s, %s) "
                        f"RETURNING {_COLUMNAS}",
                        ((() if generar else (vuelo.codigo,)) + (
                            vuelo.origen, vuelo.destino, vuelo.fecha, vuelo.hora_salida, vuelo.hora_llegada,
                            vuelo.precio, vuelo.capacidad, vuelo.asientos_disponibles,
                        )),
                    )
                    return Vuelo.from_row(cur.fetchone())
            except UniqueViolation:
                if not generar:
                    raise ConflictError(f"Ya existe un vuelo con el código {vuelo.codigo}.") from None
                # Otro vuelo tomó ese código en el mismo instante: se calcula el siguiente y se reintenta.
        raise ConflictError("No se pudo asignar un código de vuelo. Intente nuevamente.")
