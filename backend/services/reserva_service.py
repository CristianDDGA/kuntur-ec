"""Servicio Reservas: crear, listar, ver, modificar y cancelar, eligiendo asientos concretos.

Control de concurrencia: se aplican las técnicas vistas en clase, pero en la BD
(un threading.Lock solo protege un proceso; la BD protege a todos los servidores).

1. Los asientos se descuentan con UN solo UPDATE condicional:
       UPDATE vuelos SET asientos_disponibles = asientos_disponibles - n
       WHERE id = ? AND asientos_disponibles >= n
   PostgreSQL bloquea la fila mientras lo ejecuta: si dos peticiones llegan a la
   vez, la segunda espera, vuelve a evaluar la condición con el valor ya
   descontado y, si no alcanza, no actualiza nada -> 409. Nunca hay sobreventa.
2. Cada asiento concreto es único por vuelo mientras su reserva esté activa
   (índice único parcial en `reserva_asientos`): si dos personas piden el mismo
   asiento a la vez, una recibe 409 y su transacción se deshace entera.
3. Cada operación es UNA transacción: si falla un paso (p. ej. el INSERT de los
   asientos) se deshace también el descuento del contador.
4. Bloqueo (pesimista): modificar y cancelar bloquean primero la reserva
   (SELECT ... FOR UPDATE), así dos cancelaciones simultáneas no devuelven los
   asientos dos veces.
5. Versión (optimista): al modificar, el cliente envía la `version` que leyó.
   Si otro la cambió antes -> 409 "Ya actualizaron este registro" + version_actual.
   Cada UPDATE de vuelos y reservas hace `version = version + 1`.
6. Además, la BD tiene CHECK (asientos_disponibles BETWEEN 0 AND capacidad).

El cliente elige asientos con `asientos: ["1A", "2B"]`. Si envía solo `cantidad`, el sistema
asigna los primeros asientos libres (útil para integraciones simples).
"""
from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import date, datetime, time
from typing import Any

from psycopg import Cursor
from psycopg.errors import UniqueViolation

from database import Database
from models import EstadoReserva, Reserva, TarifaIva, Vuelo
from services.auth_service import Sesion
from utils.asientos import etiquetas, lista_de_asientos, orden, validar_existen
from utils.excepciones import ConflictError, NotFoundError, ValidationError
from utils.limites import ASIENTOS_POR_RESERVA as MAX_ASIENTOS_POR_RESERVA
from utils.paginacion import leer_pagina, total_paginas
from utils.validaciones import MAX_VERSION, entero, identificador

_COLUMNAS_VUELO = (
    "id, codigo, origen, destino, fecha, hora_salida, hora_llegada, "
    "precio, capacidad, asientos_disponibles, version"
)
_COLUMNAS_RESERVA = (
    "id, usuario_id, vuelo_id, cantidad_asientos, subtotal, iva_porcentaje, "
    "iva_valor, total, estado, fecha_reserva, version"
)
_RESUMEN_VUELO = ("codigo", "origen", "destino", "fecha", "hora_salida", "hora_llegada")
_REGISTRO_MODIFICADO = "Ya actualizaron este registro. Consulte la reserva y vuelva a intentarlo."
_ASIENTO_TOMADO = "Uno o más asientos ya fueron reservados por otra persona. Actualice el mapa y elija de nuevo."
# Asientos de una reserva, ordenados por fila y columna ("2A" antes que "10A").
_ASIENTOS_DE_LA_RESERVA = (
    "(SELECT array_agg(a.asiento ORDER BY length(a.asiento), a.asiento) "
    "FROM reserva_asientos a WHERE a.reserva_id = r.id) AS asientos"
)


@dataclass(frozen=True)
class ReservaDetalle:
    """Reserva + datos del vuelo + asientos, para que el cliente no tenga que pedirlos aparte."""

    reserva: Reserva
    vuelo: Vuelo
    asientos: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        return self.reserva.to_dict() | {
            "asientos": list(self.asientos),
            "vuelo": {k: getattr(self.vuelo, k) for k in _RESUMEN_VUELO},
        }


@dataclass(frozen=True)
class PaginaReservas:
    """Una página del historial de reservas y los datos para pedir las demás."""

    reservas: list[ReservaDetalle]
    total: int
    pagina: int
    por_pagina: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "total": self.total,
            "pagina": self.pagina,
            "por_pagina": self.por_pagina,
            "total_paginas": total_paginas(self.total, self.por_pagina),
            "reservas": [r.to_dict() for r in self.reservas],
        }


def _cantidad(datos: dict) -> int:
    return entero(datos, "cantidad", 1, MAX_ASIENTOS_POR_RESERVA)


def _asientos_pedidos(datos: dict) -> list[str] | None:
    """Lista de asientos elegida por el cliente, o None si solo envió `cantidad`."""
    return lista_de_asientos(datos["asientos"]) if "asientos" in datos else None


class ReservaService:
    def __init__(self, db: Database, ahora: Callable[[], datetime] = datetime.now):
        self._db = db
        self._ahora = ahora  # inyectable en pruebas; misma hora local que usa el servicio de vuelos

    def _momento(self) -> tuple[date, time]:
        """Fecha y hora (al minuto) actuales: un vuelo parte cuando llega su fecha y hora de salida."""
        ahora = self._ahora()
        return ahora.date(), ahora.time().replace(second=0, microsecond=0)

    def _ya_partio(self, vuelo: Vuelo) -> bool:
        hoy, hora = self._momento()
        return (vuelo.fecha, vuelo.hora_salida) <= (hoy, hora)

    # ------------------------------------------------------------ crear

    def crear(self, sesion: Sesion, datos: dict) -> ReservaDetalle:
        vuelo_id = identificador(datos, "vuelo_id")
        pedidos = _asientos_pedidos(datos)
        cantidad = len(pedidos) if pedidos is not None else _cantidad(datos)
        hoy, hora = self._momento()

        with self._db.transaccion() as cur:
            tarifa = self._tarifa_vigente(cur)
            cur.execute(
                "UPDATE vuelos SET asientos_disponibles = asientos_disponibles - %s, version = version + 1 "
                "WHERE id = %s AND asientos_disponibles >= %s "
                "AND (fecha > %s OR (fecha = %s AND hora_salida > %s)) "
                f"RETURNING {_COLUMNAS_VUELO}",
                (cantidad, vuelo_id, cantidad, hoy, hoy, hora),
            )
            fila = cur.fetchone()
            if fila is None:
                self._explicar_rechazo(cur, vuelo_id)
            vuelo = Vuelo.from_row(fila)

            if pedidos is None:  # asignación automática: los primeros libres
                asientos = self._elegir_libres(cur, vuelo, cantidad)
            else:
                validar_existen(pedidos, vuelo.capacidad)
                self._exigir_libres(cur, vuelo_id, pedidos)
                asientos = pedidos

            # Los montos se calculan con el estado del vuelo ANTES del descuento.
            antes = replace(vuelo, asientos_disponibles=vuelo.asientos_disponibles + cantidad)
            nueva = Reserva.nueva(sesion.usuario_id, antes, cantidad, tarifa)
            cur.execute(
                "INSERT INTO reservas (usuario_id, vuelo_id, cantidad_asientos, subtotal, "
                "iva_porcentaje, iva_valor, total, estado) VALUES (%s, %s, %s, %s, %s, %s, %s, %s) "
                f"RETURNING {_COLUMNAS_RESERVA}",
                (
                    nueva.usuario_id, nueva.vuelo_id, nueva.cantidad_asientos, nueva.subtotal,
                    nueva.iva_porcentaje, nueva.iva_valor, nueva.total, nueva.estado.value,
                ),
            )
            reserva = Reserva.from_row(cur.fetchone())
            self._guardar_asientos(cur, reserva.id, vuelo_id, asientos)
            return ReservaDetalle(reserva, vuelo, tuple(asientos))

    # ------------------------------------------------------------ consultar

    def listar(self, sesion: Sesion, pagina: str | None = None, por_pagina: str | None = None) -> PaginaReservas:
        """Reservas del usuario, la más reciente primero, paginadas."""
        numero, tamano = leer_pagina(pagina, por_pagina)
        with self._db.transaccion() as cur:
            cur.execute("SELECT count(*) AS total FROM reservas WHERE usuario_id = %s", (sesion.usuario_id,))
            total = cur.fetchone()["total"]
            cur.execute(
                f"SELECT {self._columnas_con_vuelo()} FROM reservas r JOIN vuelos v ON v.id = r.vuelo_id "
                "WHERE r.usuario_id = %s ORDER BY r.fecha_reserva DESC, r.id DESC LIMIT %s OFFSET %s",
                (sesion.usuario_id, tamano, (numero - 1) * tamano),
            )
            return PaginaReservas([self._detalle(f) for f in cur.fetchall()], total, numero, tamano)

    def obtener(self, sesion: Sesion, reserva_id: int) -> ReservaDetalle:
        with self._db.transaccion() as cur:
            return self._buscar_propia(cur, sesion, reserva_id, bloquear=False)

    # ------------------------------------------------------------ modificar / cancelar

    def modificar(self, sesion: Sesion, reserva_id: int, datos: dict) -> ReservaDetalle:
        pedidos = _asientos_pedidos(datos)
        nueva_cantidad = len(pedidos) if pedidos is not None else _cantidad(datos)
        version = entero(datos, "version", 1, MAX_VERSION)
        with self._db.transaccion() as cur:
            actual = self._buscar_propia(cur, sesion, reserva_id, bloquear=True)
            if actual.reserva.version != version:
                raise ConflictError(_REGISTRO_MODIFICADO, version_actual=actual.reserva.version)
            self._validar_editable(actual, "modificar")

            actuales = list(actual.asientos)
            if pedidos is not None:
                validar_existen(pedidos, actual.vuelo.capacidad)
                nuevos = pedidos
            elif nueva_cantidad <= len(actuales):  # solo cantidad: se quitan los últimos asientos
                nuevos = actuales[:nueva_cantidad]
            else:  # solo cantidad: se agregan los primeros libres
                extra = self._elegir_libres(
                    cur, actual.vuelo, nueva_cantidad - len(actuales),
                    sin_asientos="No hay suficientes asientos disponibles para ampliar la reserva.",
                )
                nuevos = sorted(actuales + extra, key=orden)
            if nuevos == actuales:
                return actual

            quitar = [a for a in actuales if a not in nuevos]
            agregar = [a for a in nuevos if a not in actuales]
            self._exigir_libres(cur, actual.vuelo.id, agregar)

            diferencia = len(nuevos) - len(actuales)
            if diferencia > 0:  # más asientos: descuento atómico, igual que al crear
                cur.execute(
                    "UPDATE vuelos SET asientos_disponibles = asientos_disponibles - %s, version = version + 1 "
                    f"WHERE id = %s AND asientos_disponibles >= %s RETURNING {_COLUMNAS_VUELO}",
                    (diferencia, actual.vuelo.id, diferencia),
                )
                fila_vuelo = cur.fetchone()
                if fila_vuelo is None:
                    raise ConflictError("No hay suficientes asientos disponibles para ampliar la reserva.")
                vuelo = Vuelo.from_row(fila_vuelo)
            elif diferencia < 0:  # menos asientos: se devuelven
                cur.execute(
                    "UPDATE vuelos SET asientos_disponibles = asientos_disponibles + %s, version = version + 1 "
                    f"WHERE id = %s RETURNING {_COLUMNAS_VUELO}",
                    (-diferencia, actual.vuelo.id),
                )
                vuelo = Vuelo.from_row(cur.fetchone())
            else:  # cambio de lugares con la misma cantidad
                vuelo = actual.vuelo

            if quitar:
                cur.execute(
                    "DELETE FROM reserva_asientos WHERE reserva_id = %s AND asiento = ANY(%s)",
                    (reserva_id, quitar),
                )
            self._guardar_asientos(cur, reserva_id, actual.vuelo.id, agregar)

            # Se respetan el precio y el IVA con los que se hizo la reserva.
            precio_unitario = actual.reserva.subtotal / actual.reserva.cantidad_asientos
            desglose = TarifaIva(
                id=None, porcentaje=actual.reserva.iva_porcentaje, vigente_desde=date.min, vigente_hasta=None
            ).calcular(precio_unitario * len(nuevos))
            cur.execute(
                "UPDATE reservas SET cantidad_asientos = %s, subtotal = %s, iva_valor = %s, total = %s, "
                "version = version + 1 "
                f"WHERE id = %s AND version = %s RETURNING {_COLUMNAS_RESERVA}",
                (len(nuevos), desglose.subtotal, desglose.iva_valor, desglose.total, reserva_id, version),
            )
            fila = cur.fetchone()
            if fila is None:  # no debería pasar (la fila está bloqueada), pero se respeta la regla
                raise ConflictError(_REGISTRO_MODIFICADO, version_actual=actual.reserva.version)
            return ReservaDetalle(Reserva.from_row(fila), vuelo, tuple(nuevos))

    def cancelar(self, sesion: Sesion, reserva_id: int) -> ReservaDetalle:
        with self._db.transaccion() as cur:
            actual = self._buscar_propia(cur, sesion, reserva_id, bloquear=True)
            self._validar_editable(actual, "cancelar")
            cur.execute(
                "UPDATE reservas SET estado = %s, version = version + 1 WHERE id = %s RETURNING " + _COLUMNAS_RESERVA,
                (EstadoReserva.CANCELADA.value, reserva_id),
            )
            reserva = Reserva.from_row(cur.fetchone())
            # Los asientos quedan en el historial de la reserva pero se liberan para otros.
            cur.execute("UPDATE reserva_asientos SET activo = FALSE WHERE reserva_id = %s", (reserva_id,))
            cur.execute(
                "UPDATE vuelos SET asientos_disponibles = asientos_disponibles + %s, version = version + 1 "
                f"WHERE id = %s RETURNING {_COLUMNAS_VUELO}",
                (reserva.cantidad_asientos, reserva.vuelo_id),
            )
            return ReservaDetalle(reserva, Vuelo.from_row(cur.fetchone()), actual.asientos)

    # ------------------------------------------------------------ asientos

    @staticmethod
    def _ocupados(cur: Cursor, vuelo_id: int, entre: list[str] | None = None) -> set[str]:
        """Asientos del vuelo que ya tienen una reserva activa (opcionalmente, solo entre `entre`)."""
        sql = (
            "SELECT coalesce(array_agg(asiento), ARRAY[]::varchar[]) AS ocupados "
            "FROM reserva_asientos WHERE vuelo_id = %s AND activo"
        )
        params: tuple = (vuelo_id,)
        if entre is not None:
            sql += " AND asiento = ANY(%s)"
            params = (vuelo_id, entre)
        cur.execute(sql, params)
        return set(cur.fetchone()["ocupados"])

    def _exigir_libres(self, cur: Cursor, vuelo_id: int, asientos: list[str]) -> None:
        """409 con la lista de asientos que ya no están libres (para que la app los quite de la selección)."""
        if not asientos:
            return
        tomados = self._ocupados(cur, vuelo_id, asientos)
        if tomados:
            raise ConflictError(_ASIENTO_TOMADO, asientos_ocupados=sorted(tomados, key=orden))

    def _elegir_libres(
        self, cur: Cursor, vuelo: Vuelo, cantidad: int, sin_asientos: str = "No hay suficientes asientos disponibles en el vuelo."
    ) -> list[str]:
        """Los primeros `cantidad` asientos libres del vuelo (cuando el cliente no eligió asientos concretos)."""
        ocupados = self._ocupados(cur, vuelo.id)
        libres = [e for e in etiquetas(vuelo.capacidad) if e not in ocupados]
        if len(libres) < cantidad:
            raise ConflictError(sin_asientos)
        return libres[:cantidad]

    @staticmethod
    def _guardar_asientos(cur: Cursor, reserva_id: int, vuelo_id: int, asientos: list[str]) -> None:
        if not asientos:
            return
        try:
            cur.executemany(
                "INSERT INTO reserva_asientos (reserva_id, vuelo_id, asiento) VALUES (%s, %s, %s)",
                [(reserva_id, vuelo_id, a) for a in asientos],
            )
        except UniqueViolation:  # otra persona los tomó en este mismo instante
            raise ConflictError(_ASIENTO_TOMADO) from None

    # ------------------------------------------------------------ apoyo

    @staticmethod
    def _tarifa_vigente(cur: Cursor) -> TarifaIva:
        cur.execute(
            "SELECT id, porcentaje, vigente_desde, vigente_hasta FROM tarifas_iva "
            "WHERE vigente_desde <= current_date AND (vigente_hasta IS NULL OR vigente_hasta > current_date) "
            "ORDER BY vigente_desde DESC LIMIT 1"
        )
        fila = cur.fetchone()
        if fila is None:
            raise ConflictError("No hay una tarifa de IVA vigente configurada.")
        return TarifaIva.from_row(fila)

    def _explicar_rechazo(self, cur: Cursor, vuelo_id: int) -> None:
        """El UPDATE no afectó filas: averigua por qué para responder el error correcto."""
        cur.execute(f"SELECT {_COLUMNAS_VUELO} FROM vuelos WHERE id = %s", (vuelo_id,))
        fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El vuelo solicitado no existe.")
        if self._ya_partio(Vuelo.from_row(fila)):
            raise ValidationError("No se puede reservar un vuelo que ya partió.")
        raise ConflictError("No hay suficientes asientos disponibles en el vuelo.")

    @staticmethod
    def _columnas_con_vuelo() -> str:
        reserva = ", ".join(f"r.{c.strip()}" for c in _COLUMNAS_RESERVA.split(","))
        vuelo = ", ".join(f"v.{c.strip()} AS v_{c.strip()}" for c in _COLUMNAS_VUELO.split(","))
        return f"{reserva}, {vuelo}, {_ASIENTOS_DE_LA_RESERVA}"

    @staticmethod
    def _detalle(fila: dict[str, Any]) -> ReservaDetalle:
        vuelo = {k[2:]: v for k, v in fila.items() if k.startswith("v_")}
        return ReservaDetalle(Reserva.from_row(fila), Vuelo.from_row(vuelo), tuple(fila.get("asientos") or ()))

    def _buscar_propia(self, cur: Cursor, sesion: Sesion, reserva_id: int, bloquear: bool) -> ReservaDetalle:
        # Una reserva ajena responde 404 (no se revela que existe).
        cur.execute(
            f"SELECT {self._columnas_con_vuelo()} FROM reservas r JOIN vuelos v ON v.id = r.vuelo_id "
            "WHERE r.id = %s AND r.usuario_id = %s" + (" FOR UPDATE OF r" if bloquear else ""),
            (reserva_id, sesion.usuario_id),
        )
        fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("La reserva solicitada no existe.")
        return self._detalle(fila)

    def _validar_editable(self, detalle: ReservaDetalle, accion: str) -> None:
        if detalle.reserva.esta_cancelada:
            raise ConflictError(f"No se puede {accion} una reserva cancelada.")
        if self._ya_partio(detalle.vuelo):
            raise ValidationError(f"No se puede {accion} la reserva de un vuelo que ya partió.")
