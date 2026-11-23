"""Servicio Vuelos: búsqueda y detalle; crear, editar y cancelar (solo administrador).

Editar y cancelar siguen las mismas reglas de concurrencia que las reservas: bloquean la fila
del vuelo (SELECT ... FOR UPDATE) y exigen la `version` que leyó el administrador (409 si otro
la cambió antes). Un vuelo nunca se borra: al cancelarlo queda en el historial con su motivo y
sus reservas confirmadas pasan a canceladas, liberando los asientos.
"""
from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import date, datetime, time, timedelta
from typing import Any

from psycopg import Cursor
from psycopg.errors import UniqueViolation

from database import Database
from models import EstadoReserva, EstadoVuelo, Vuelo
from utils.asientos import COLUMNAS
from utils.excepciones import ConflictError, NotFoundError, ValidationError
from utils.paginacion import leer_pagina, total_paginas
from utils.reloj import ahora_ecuador
from utils.limites import CAPACIDAD_MAXIMA as MAX_CAPACIDAD
from utils.limites import CIUDAD as MAX_LARGO_CIUDAD
from utils.limites import CODIGO_VUELO as MAX_LARGO_CODIGO
from utils.limites import MOTIVO_CANCELACION as MAX_LARGO_MOTIVO
from utils.limites import MOTIVO_MINIMO
from utils.validaciones import (
    MAX_VERSION,
    entero,
    fecha_iso,
    identificador,
    hora_hhmm,
    nombre_propio,
    precio,
    revisar_texto,
    texto_obligatorio,
)

_COLUMNAS = (
    "id, codigo, origen, destino, fecha, hora_salida, hora_llegada, "
    "precio, capacidad, asientos_disponibles, version, avion_id, estado, motivo_cancelacion"
)
# Solo los vuelos programados se venden y aparecen en la búsqueda pública.
_PROGRAMADO = f"estado = '{EstadoVuelo.PROGRAMADO.value}'"
_REGISTRO_MODIFICADO = "Ya actualizaron este vuelo. Consúltelo de nuevo y vuelva a intentarlo."
# Campos que el administrador puede cambiar al editar (el código y los asientos vendidos no).
_EDITABLES = ("origen", "destino", "fecha", "hora_salida", "hora_llegada", "precio", "avion_id")
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


@dataclass(frozen=True)
class PaginaGestion(PaginaVuelos):
    """Listado del administrador: cada vuelo con lo que necesita para decidir si editarlo o cancelarlo."""

    ahora: tuple[date, time] = (date.min, time.min)

    def to_dict(self) -> dict:
        datos = super().to_dict()
        datos["vuelos"] = [
            v.to_dict() | {
                "ya_partio": (v.fecha, v.hora_salida) <= self.ahora,
                "asientos_vendidos": v.capacidad - v.asientos_disponibles,
            }
            for v in self.vuelos
        ]
        return datos


@dataclass(frozen=True)
class VueloCancelado:
    vuelo: Vuelo
    reservas_canceladas: int

    def to_dict(self) -> dict[str, Any]:
        return {"vuelo": self.vuelo.to_dict(), "reservas_canceladas": self.reservas_canceladas}


def _motivo(datos: dict) -> str:
    """Motivo de la cancelación: lo leen los pasajeros, así que debe explicar algo."""
    motivo = texto_obligatorio(datos, "motivo", MAX_LARGO_MOTIVO)
    if sum(c.isalpha() for c in motivo) < MOTIVO_MINIMO:
        raise ValidationError(
            f"El motivo debe tener al menos {MOTIVO_MINIMO} letras para que el pasajero entienda qué pasó."
        )
    return motivo


# ---------------------------------------------------------------- servicio


class VueloService:
    def __init__(
        self,
        db: Database,
        hoy: Callable[[], date] | None = None,
        ahora: Callable[[], datetime] = ahora_ecuador,
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
        condiciones = [_PROGRAMADO, "(fecha > %s OR (fecha = %s AND hora_salida > %s))"]
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

    def destinos(self, limite: int = 8) -> dict:
        """Destinos con vuelos próximos y la tarifa más baja de cada uno (para la portada pública)."""
        with self._db.transaccion() as cur:
            cur.execute(
                "SELECT min(destino) AS destino, min(precio) AS precio_minimo, count(*) AS vuelos "
                f"FROM vuelos WHERE {_PROGRAMADO} AND (fecha > %s OR (fecha = %s AND hora_salida > %s)) "
                "GROUP BY lower(destino) ORDER BY min(precio), min(destino) LIMIT %s",
                (self._hoy(), self._hoy(), self._hora_actual(), limite),
            )
            filas = cur.fetchall()
        return {
            "destinos": [
                {"destino": f["destino"], "precio_minimo": f"{f['precio_minimo']:.2f}", "vuelos": f["vuelos"]}
                for f in filas
            ]
        }

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

    def _capacidad_del_avion(self, avion_id: int, cur: Cursor | None = None) -> int:
        if cur is None:
            with self._db.transaccion() as nuevo:
                return self._capacidad_del_avion(avion_id, nuevo)
        cur.execute("SELECT filas FROM aviones WHERE id = %s", (avion_id,))
        fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El avión indicado no existe.")
        return fila["filas"] * len(COLUMNAS)

    def _ya_partio(self, vuelo: Vuelo) -> bool:
        return (vuelo.fecha, vuelo.hora_salida) <= (self._hoy(), self._hora_actual())

    def _validar_programacion(self, vuelo: Vuelo) -> None:
        """Reglas de fecha y hora comunes a crear y editar."""
        if vuelo.fecha < self._hoy():
            raise ValidationError("La fecha del vuelo no puede ser pasada.")
        if vuelo.fecha == self._hoy() and vuelo.hora_salida <= self._hora_actual():
            raise ValidationError(
                f"La hora de salida ya pasó: para hoy elija una hora posterior a las {self._hora_actual():%H:%M}."
            )
        if vuelo.fecha > self._hoy() + timedelta(days=MAX_DIAS_ADELANTE):
            raise ValidationError("La fecha del vuelo no puede superar los 2 años desde hoy.")
        if vuelo.hora_llegada == vuelo.hora_salida:
            raise ValidationError("La hora de llegada debe ser distinta a la de salida.")

    def crear(self, datos: dict) -> Vuelo:
        """Crea un vuelo. Si `datos` trae `codigo` se respeta; si no, el sistema genera el siguiente (KT101, KT102...)."""
        avion_id = identificador(datos, "avion_id") if datos.get("avion_id") is not None else None
        # Con avión, la capacidad es la del avión (filas x 4); sin avión se sigue aceptando `capacidad`.
        capacidad = self._capacidad_del_avion(avion_id) if avion_id else entero(datos, "capacidad", 1, MAX_CAPACIDAD)
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
        self._validar_programacion(vuelo)

        for intento in range(INTENTOS_CODIGO if generar else 1):
            try:
                with self._db.transaccion() as cur:
                    cur.execute(
                        "INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada, "
                        "precio, capacidad, asientos_disponibles, avion_id) "
                        f"VALUES ({_SQL_CODIGO_NUEVO if generar else '%s'}, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
                        f"RETURNING {_COLUMNAS}",
                        ((() if generar else (vuelo.codigo,)) + (
                            vuelo.origen, vuelo.destino, vuelo.fecha, vuelo.hora_salida, vuelo.hora_llegada,
                            vuelo.precio, vuelo.capacidad, vuelo.asientos_disponibles, avion_id,
                        )),
                    )
                    return Vuelo.from_row(cur.fetchone())
            except UniqueViolation:
                if not generar:
                    raise ConflictError(f"Ya existe un vuelo con el código {vuelo.codigo}.") from None
                # Otro vuelo tomó ese código en el mismo instante: se calcula el siguiente y se reintenta.
        raise ConflictError("No se pudo asignar un código de vuelo. Intente nuevamente.")

    # ------------------------------------------------------------ administración

    def gestion(self, pagina: str | None = None, por_pagina: str | None = None, estado: str | None = None) -> PaginaGestion:
        """Todos los vuelos (también cancelados y ya partidos): primero los próximos, luego el historial."""
        numero, tamano = leer_pagina(pagina, por_pagina)
        donde, params = "", ()
        if estado not in (None, ""):
            if estado not in {e.value for e in EstadoVuelo}:
                raise ValidationError("El filtro 'estado' debe ser 'programado' o 'cancelado'.")
            donde, params = "WHERE estado = %s", (estado,)
        hoy, hora = self._hoy(), self._hora_actual()
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT count(*) AS total FROM vuelos {donde}", params)
            total = cur.fetchone()["total"]
            cur.execute(
                f"SELECT {_COLUMNAS} FROM vuelos {donde} "
                "ORDER BY (fecha, hora_salida) <= (%s, %s), "  # false (aún no parte) va primero
                "CASE WHEN (fecha, hora_salida) > (%s, %s) THEN fecha END, "
                "CASE WHEN (fecha, hora_salida) > (%s, %s) THEN hora_salida END, "
                "fecha DESC, hora_salida DESC, codigo LIMIT %s OFFSET %s",
                (*params, hoy, hora, hoy, hora, hoy, hora, tamano, (numero - 1) * tamano),
            )
            vuelos = [Vuelo.from_row(f) for f in cur.fetchall()]
        return PaginaGestion(vuelos, total, numero, tamano, ahora=(hoy, hora))

    def _bloquear(self, cur: Cursor, vuelo_id: int, version: int, accion: str) -> Vuelo:
        """Bloquea la fila del vuelo y comprueba que se pueda `accion` (editar o cancelar)."""
        cur.execute(f"SELECT {_COLUMNAS} FROM vuelos WHERE id = %s FOR UPDATE", (vuelo_id,))
        fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El vuelo solicitado no existe.")
        vuelo = Vuelo.from_row(fila)
        if vuelo.version != version:
            raise ConflictError(_REGISTRO_MODIFICADO, version_actual=vuelo.version)
        if vuelo.esta_cancelado:
            raise ConflictError(f"No se puede {accion} un vuelo cancelado.")
        if self._ya_partio(vuelo):
            raise ValidationError(f"No se puede {accion} un vuelo que ya partió.")
        return vuelo

    def editar(self, vuelo_id: int, datos: dict) -> Vuelo:
        """Cambia la programación del vuelo. Con asientos vendidos no se puede cambiar la ruta ni el avión."""
        version = entero(datos, "version", 1, MAX_VERSION)
        desconocidos = set(datos) - set(_EDITABLES) - {"version"}
        if desconocidos:
            raise ValidationError(f"Estos campos no se pueden editar: {', '.join(sorted(desconocidos))}.")
        origen = nombre_propio(datos, "origen", MAX_LARGO_CIUDAD)
        destino = nombre_propio(datos, "destino", MAX_LARGO_CIUDAD)
        fecha = fecha_iso(datos.get("fecha"))
        salida = hora_hhmm(datos.get("hora_salida"), "hora_salida")
        llegada = hora_hhmm(datos.get("hora_llegada"), "hora_llegada")
        nuevo_precio = precio(datos)
        avion_id = identificador(datos, "avion_id") if datos.get("avion_id") is not None else None

        with self._db.transaccion() as cur:
            actual = self._bloquear(cur, vuelo_id, version, "editar")
            cambia_ruta = (origen.lower(), destino.lower()) != (actual.origen.lower(), actual.destino.lower())
            cambia_avion = avion_id is not None and avion_id != actual.avion_id
            if actual.tiene_reservas and (cambia_ruta or cambia_avion):
                vendidos = actual.capacidad - actual.asientos_disponibles
                que = "la ruta" if cambia_ruta else "el avión"
                raise ConflictError(
                    f"El vuelo ya tiene {vendidos} asiento(s) vendido(s): no se puede cambiar {que}. "
                    "Si es necesario, cancele el vuelo y cree otro."
                )
            capacidad = self._capacidad_del_avion(avion_id, cur) if cambia_avion else actual.capacidad
            nuevo = replace(  # el modelo vuelve a validar origen ≠ destino, precio y asientos
                actual,
                origen=origen, destino=destino, fecha=fecha, hora_salida=salida, hora_llegada=llegada,
                precio=nuevo_precio, capacidad=capacidad,
                asientos_disponibles=capacidad if cambia_avion else actual.asientos_disponibles,
                avion_id=avion_id if cambia_avion else actual.avion_id,
            )
            if nuevo == actual:
                return actual
            horario_actual = (actual.fecha, actual.hora_salida, actual.hora_llegada)
            if (nuevo.fecha, nuevo.hora_salida, nuevo.hora_llegada) != horario_actual:
                self._validar_programacion(nuevo)
            cur.execute(
                "UPDATE vuelos SET origen = %s, destino = %s, fecha = %s, hora_salida = %s, hora_llegada = %s, "
                "precio = %s, capacidad = %s, asientos_disponibles = %s, avion_id = %s, version = version + 1 "
                f"WHERE id = %s AND version = %s RETURNING {_COLUMNAS}",
                (
                    nuevo.origen, nuevo.destino, nuevo.fecha, nuevo.hora_salida, nuevo.hora_llegada,
                    nuevo.precio, nuevo.capacidad, nuevo.asientos_disponibles, nuevo.avion_id, vuelo_id, version,
                ),
            )
            fila = cur.fetchone()
            if fila is None:  # no debería pasar (la fila está bloqueada), pero se respeta la regla
                raise ConflictError(_REGISTRO_MODIFICADO, version_actual=actual.version)
            return Vuelo.from_row(fila)

    def cancelar(self, vuelo_id: int, datos: dict) -> VueloCancelado:
        """Cancela el vuelo y todas sus reservas confirmadas en UNA transacción, liberando los asientos."""
        version = entero(datos, "version", 1, MAX_VERSION)
        motivo = _motivo(datos)
        with self._db.transaccion() as cur:
            # Mismo orden de bloqueo que al modificar o cancelar una reserva (primero las reservas,
            # luego el vuelo): así dos operaciones simultáneas esperan su turno sin trabarse entre sí.
            cur.execute(
                "SELECT id FROM reservas WHERE vuelo_id = %s AND estado = %s ORDER BY id FOR UPDATE",
                (vuelo_id, EstadoReserva.CONFIRMADA.value),
            )  # solo bloquea: las filas no se necesitan
            self._bloquear(cur, vuelo_id, version, "cancelar")
            cur.execute(
                "UPDATE reservas SET estado = %s, version = version + 1 WHERE vuelo_id = %s AND estado = %s",
                (EstadoReserva.CANCELADA.value, vuelo_id, EstadoReserva.CONFIRMADA.value),
            )
            canceladas = cur.rowcount
            # Los asientos quedan en el historial de cada reserva, pero ya no ocupan el vuelo.
            cur.execute("UPDATE reserva_asientos SET activo = FALSE WHERE vuelo_id = %s AND activo", (vuelo_id,))
            cur.execute(
                "UPDATE vuelos SET estado = %s, motivo_cancelacion = %s, asientos_disponibles = capacidad, "
                f"version = version + 1 WHERE id = %s RETURNING {_COLUMNAS}",
                (EstadoVuelo.CANCELADO.value, motivo, vuelo_id),
            )
            return VueloCancelado(Vuelo.from_row(cur.fetchone()), canceladas)
