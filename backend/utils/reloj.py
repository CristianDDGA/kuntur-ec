"""Hora oficial de Ecuador, sin depender de la zona horaria del servidor.

Los vuelos guardan fecha y hora locales de Ecuador. En Render el servidor (y Supabase) trabajan
en UTC, cinco horas adelante: desde las 19:00 de Ecuador ya "es mañana" y un vuelo de hoy se
rechazaría como fecha pasada. Por eso toda comparación con "ahora" usa este reloj.
"""
from datetime import date, datetime, timedelta, timezone

# Ecuador continental: UTC-5 todo el año (no aplica horario de verano).
ZONA_ECUADOR = timezone(timedelta(hours=-5), "ECT")


def ahora_ecuador() -> datetime:
    """Fecha y hora actuales de Ecuador, sin zona (igual que las columnas fecha/hora de la base)."""
    return datetime.now(ZONA_ECUADOR).replace(tzinfo=None)


def hoy_ecuador() -> date:
    """Fecha actual de Ecuador."""
    return ahora_ecuador().date()
