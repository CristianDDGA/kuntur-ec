"""Servicio IVA: consulta del historial de tarifas y cambio de la tarifa (solo administrador).

Cambiar el IVA nunca modifica reservas ya hechas: ellas guardan el porcentaje con el que se
cobraron. La tarifa nueva se aplica a las reservas que se creen desde su fecha de inicio.
"""
from __future__ import annotations

from collections.abc import Callable
from datetime import date, timedelta
from typing import Any

from database import Database
from models import TarifaIva
from utils.excepciones import ConflictError, ValidationError
from utils.validaciones import fecha_iso, porcentaje

MAX_DIAS_ADELANTE = 730
_COLUMNAS = "id, porcentaje, vigente_desde, vigente_hasta"


def _describir(tarifa: TarifaIva, hoy: date) -> dict[str, Any]:
    if tarifa.vigente_en(hoy):
        estado = "vigente"
    elif tarifa.vigente_desde > hoy:
        estado = "programada"
    else:
        estado = "anterior"
    return {**tarifa.to_dict(), "estado": estado}


class IvaService:
    def __init__(self, db: Database, hoy: Callable[[], date] = date.today):
        self._db = db
        self._hoy = hoy  # inyectable para las pruebas

    def consultar(self) -> dict[str, Any]:
        """Tarifa vigente hoy y todo el historial (la más reciente primero)."""
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM tarifas_iva ORDER BY vigente_desde DESC")
            tarifas = [_describir(TarifaIva.from_row(f), self._hoy()) for f in cur.fetchall()]
        vigente = next((t for t in tarifas if t["estado"] == "vigente"), None)
        return {"vigente": vigente, "tarifas": tarifas}

    def cambiar(self, datos: dict) -> dict[str, Any]:
        """Programa una tarifa nueva: cierra la abierta el día anterior y abre la nueva."""
        nuevo = porcentaje(datos)
        desde = fecha_iso(datos.get("vigente_desde"), "vigente_desde")
        hoy = self._hoy()
        if desde < hoy:
            raise ValidationError("La nueva tarifa no puede empezar en el pasado: no se cambian reservas ya hechas.")
        if desde > hoy + timedelta(days=MAX_DIAS_ADELANTE):
            raise ValidationError("La fecha de inicio no puede superar los 2 años desde hoy.")

        with self._db.transaccion() as cur:
            # Dos administradores a la vez: el segundo espera y ve el resultado del primero.
            cur.execute("LOCK TABLE tarifas_iva IN EXCLUSIVE MODE")
            cur.execute("SELECT max(vigente_desde) AS ultima FROM tarifas_iva")
            ultima = cur.fetchone()["ultima"]
            if ultima is not None and desde <= ultima:
                raise ConflictError(
                    f"Ya hay una tarifa que empieza el {ultima:%d/%m/%Y}. La nueva debe comenzar después de esa fecha."
                )
            cur.execute("UPDATE tarifas_iva SET vigente_hasta = %s WHERE vigente_hasta IS NULL", (desde,))
            cur.execute(
                f"INSERT INTO tarifas_iva (porcentaje, vigente_desde) VALUES (%s, %s) RETURNING {_COLUMNAS}",
                (nuevo, desde),
            )
            return _describir(TarifaIva.from_row(cur.fetchone()), hoy)
