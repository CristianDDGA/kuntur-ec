"""Ayuda para las pruebas con la BD real: el IVA vigente puede haberlo cambiado el administrador,
así que los totales esperados se calculan con el porcentaje que la BD tiene hoy (no con un 15 % fijo)."""
from decimal import ROUND_HALF_UP, Decimal


def porcentaje_vigente(db) -> Decimal:
    with db.transaccion() as cur:
        cur.execute(
            "SELECT porcentaje FROM tarifas_iva WHERE vigente_desde <= current_date "
            "AND (vigente_hasta IS NULL OR vigente_hasta > current_date) ORDER BY vigente_desde DESC LIMIT 1"
        )
        return cur.fetchone()["porcentaje"]


def total_con_iva(subtotal: str, porcentaje: Decimal) -> Decimal:
    """Subtotal + IVA redondeado a centavos, igual que el servicio."""
    base = Decimal(subtotal)
    iva = (base * porcentaje / 100).quantize(Decimal("0.01"), ROUND_HALF_UP)
    return base + iva
