"""Servicio Reservas: crear, listar, ver, modificar y cancelar.

Control de concurrencia: se aplican las tres técnicas vistas en clase, pero en la BD
(un threading.Lock solo protege un proceso; la BD protege a todos los servidores).

1. Los asientos se descuentan con UN solo UPDATE condicional:
       UPDATE vuelos SET asientos_disponibles = asientos_disponibles - n
       WHERE id = ? AND asientos_disponibles >= n
   PostgreSQL bloquea la fila mientras lo ejecuta: si dos peticiones llegan a la
   vez, la segunda espera, vuelve a evaluar la condición con el valor ya
   descontado y, si no alcanza, no actualiza nada -> 409. Nunca hay sobreventa.
2. Cada operación es UNA transacción: si falla un paso (p. ej. el INSERT de la
   reserva) se deshace también el descuento de asientos.
3. Bloqueo (pesimista): modificar y cancelar bloquean primero la reserva
   (SELECT ... FOR UPDATE), así dos cancelaciones simultáneas no devuelven los
   asientos dos veces.
4. Versión (optimista): al modificar, el cliente envía la `version` que leyó.
   Si otro la cambió antes -> 409 "Ya actualizaron este registro" + version_actual.
   Cada UPDATE de vuelos y reservas hace `version = version + 1`.
5. Además, la BD tiene CHECK (asientos_disponibles BETWEEN 0 AND capacidad).
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import date
from typing import Any

from psycopg import Cursor

from database import Database
from models import EstadoReserva, Reserva, TarifaIva, Vuelo
from services.auth_service import Sesion
from utils.excepciones import ConflictError, NotFoundError, ValidationError

MAX_ASIENTOS_POR_RESERVA = 10

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


@dataclass(frozen=True)
class ReservaDetalle:
    """Reserva + datos del vuelo, para que el cliente no tenga que pedirlos aparte."""

    reserva: Reserva
    vuelo: Vuelo

    def to_dict(self) -> dict[str, Any]:
        return self.reserva.to_dict() | {"vuelo": {k: getattr(self.vuelo, k) for k in _RESUMEN_VUELO}}


def _entero(datos: dict, campo: str) -> int:
    valor = datos.get(campo)
    if isinstance(valor, bool) or not isinstance(valor, int):
        raise ValidationError(f"El campo '{campo}' es obligatorio y debe ser un número entero.")
    return valor


def _cantidad(datos: dict) -> int:
    cantidad = _entero(datos, "cantidad")
    if not 1 <= cantidad <= MAX_ASIENTOS_POR_RESERVA:
        raise ValidationError(f"La cantidad debe estar entre 1 y {MAX_ASIENTOS_POR_RESERVA} asientos.")
    return cantidad


class ReservaService:
    def __init__(self, db: Database):
        self._db = db

    # ------------------------------------------------------------ crear

    def crear(self, sesion: Sesion, datos: dict) -> ReservaDetalle:
        vuelo_id = _entero(datos, "vuelo_id")
        cantidad = _cantidad(datos)

        with self._db.transaccion() as cur:
            tarifa = self._tarifa_vigente(cur)
            cur.execute(
                "UPDATE vuelos SET asientos_disponibles = asientos_disponibles - %s, version = version + 1 "
                "WHERE id = %s AND asientos_disponibles >= %s AND fecha >= current_date "
                f"RETURNING {_COLUMNAS_VUELO}",
                (cantidad, vuelo_id, cantidad),
            )
            fila = cur.fetchone()
            if fila is None:
                self._explicar_rechazo(cur, vuelo_id)
            vuelo = Vuelo.from_row(fila)

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
            return ReservaDetalle(Reserva.from_row(cur.fetchone()), vuelo)

    # ------------------------------------------------------------ consultar

    def listar(self, sesion: Sesion) -> list[ReservaDetalle]:
        with self._db.transaccion() as cur:
            cur.execute(
                f"SELECT {self._columnas_con_vuelo()} FROM reservas r JOIN vuelos v ON v.id = r.vuelo_id "
                "WHERE r.usuario_id = %s ORDER BY r.fecha_reserva DESC, r.id DESC",
                (sesion.usuario_id,),
            )
            return [self._detalle(fila) for fila in cur.fetchall()]

    def obtener(self, sesion: Sesion, reserva_id: int) -> ReservaDetalle:
        with self._db.transaccion() as cur:
            return self._buscar_propia(cur, sesion, reserva_id, bloquear=False)

    # ------------------------------------------------------------ modificar / cancelar

    def modificar(self, sesion: Sesion, reserva_id: int, datos: dict) -> ReservaDetalle:
        nueva_cantidad = _cantidad(datos)
        version = _entero(datos, "version")
        with self._db.transaccion() as cur:
            actual = self._buscar_propia(cur, sesion, reserva_id, bloquear=True)
            if actual.reserva.version != version:
                raise ConflictError(_REGISTRO_MODIFICADO, version_actual=actual.reserva.version)
            self._validar_editable(actual, "modificar")
            diferencia = nueva_cantidad - actual.reserva.cantidad_asientos
            if diferencia == 0:
                return actual

            if diferencia > 0:  # pide más asientos: descuento atómico, igual que al crear
                cur.execute(
                    "UPDATE vuelos SET asientos_disponibles = asientos_disponibles - %s, version = version + 1 "
                    f"WHERE id = %s AND asientos_disponibles >= %s RETURNING {_COLUMNAS_VUELO}",
                    (diferencia, actual.vuelo.id, diferencia),
                )
            else:  # devuelve asientos
                cur.execute(
                    "UPDATE vuelos SET asientos_disponibles = asientos_disponibles + %s, version = version + 1 "
                    f"WHERE id = %s RETURNING {_COLUMNAS_VUELO}",
                    (-diferencia, actual.vuelo.id),
                )
            fila_vuelo = cur.fetchone()
            if fila_vuelo is None:
                raise ConflictError("No hay suficientes asientos disponibles para ampliar la reserva.")

            # Se respetan el precio y el IVA con los que se hizo la reserva.
            precio_unitario = actual.reserva.subtotal / actual.reserva.cantidad_asientos
            desglose = TarifaIva(
                id=None, porcentaje=actual.reserva.iva_porcentaje, vigente_desde=date.min, vigente_hasta=None
            ).calcular(precio_unitario * nueva_cantidad)
            cur.execute(
                "UPDATE reservas SET cantidad_asientos = %s, subtotal = %s, iva_valor = %s, total = %s, "
                "version = version + 1 "
                f"WHERE id = %s AND version = %s RETURNING {_COLUMNAS_RESERVA}",
                (nueva_cantidad, desglose.subtotal, desglose.iva_valor, desglose.total, reserva_id, version),
            )
            fila = cur.fetchone()
            if fila is None:  # no debería pasar (la fila está bloqueada), pero se respeta la regla
                raise ConflictError(_REGISTRO_MODIFICADO, version_actual=actual.reserva.version)
            return ReservaDetalle(Reserva.from_row(fila), Vuelo.from_row(fila_vuelo))

    def cancelar(self, sesion: Sesion, reserva_id: int) -> ReservaDetalle:
        with self._db.transaccion() as cur:
            actual = self._buscar_propia(cur, sesion, reserva_id, bloquear=True)
            self._validar_editable(actual, "cancelar")
            cur.execute(
                "UPDATE reservas SET estado = %s, version = version + 1 WHERE id = %s RETURNING " + _COLUMNAS_RESERVA,
                (EstadoReserva.CANCELADA.value, reserva_id),
            )
            reserva = Reserva.from_row(cur.fetchone())
            cur.execute(
                "UPDATE vuelos SET asientos_disponibles = asientos_disponibles + %s, version = version + 1 "
                f"WHERE id = %s RETURNING {_COLUMNAS_VUELO}",
                (reserva.cantidad_asientos, reserva.vuelo_id),
            )
            return ReservaDetalle(reserva, Vuelo.from_row(cur.fetchone()))

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

    @staticmethod
    def _explicar_rechazo(cur: Cursor, vuelo_id: int) -> None:
        """El UPDATE no afectó filas: averigua por qué para responder el error correcto."""
        cur.execute("SELECT fecha >= current_date AS vigente FROM vuelos WHERE id = %s", (vuelo_id,))
        fila = cur.fetchone()
        if fila is None:
            raise NotFoundError("El vuelo solicitado no existe.")
        if not fila["vigente"]:
            raise ValidationError("No se puede reservar un vuelo que ya partió.")
        raise ConflictError("No hay suficientes asientos disponibles en el vuelo.")

    @staticmethod
    def _columnas_con_vuelo() -> str:
        reserva = ", ".join(f"r.{c.strip()}" for c in _COLUMNAS_RESERVA.split(","))
        vuelo = ", ".join(f"v.{c.strip()} AS v_{c.strip()}" for c in _COLUMNAS_VUELO.split(","))
        return f"{reserva}, {vuelo}"

    @staticmethod
    def _detalle(fila: dict[str, Any]) -> ReservaDetalle:
        vuelo = {k[2:]: v for k, v in fila.items() if k.startswith("v_")}
        return ReservaDetalle(Reserva.from_row(fila), Vuelo.from_row(vuelo))

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

    @staticmethod
    def _validar_editable(detalle: ReservaDetalle, accion: str) -> None:
        if detalle.reserva.esta_cancelada:
            raise ConflictError(f"No se puede {accion} una reserva cancelada.")
        if detalle.vuelo.fecha < date.today():
            raise ValidationError(f"No se puede {accion} la reserva de un vuelo que ya partió.")
