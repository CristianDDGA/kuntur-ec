"""Destinos de la portada contra la BD real (solo lectura: no crea datos)."""
import os

import pytest
from dotenv import load_dotenv

from database import Database
from services.vuelo_service import VueloService

load_dotenv()
URL = os.environ.get("DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Sin DATABASE_URL: se omiten las pruebas con la BD real.")


def test_destinos_agrupa_por_ciudad_y_ordena_por_tarifa():
    db = Database(URL)
    try:
        destinos = VueloService(db).destinos(limite=5)["destinos"]
    finally:
        db.cerrar()
    assert len(destinos) <= 5
    ciudades = [d["destino"].lower() for d in destinos]
    assert len(ciudades) == len(set(ciudades))  # una fila por ciudad
    precios = [float(d["precio_minimo"]) for d in destinos]
    assert precios == sorted(precios)
    assert all(d["vuelos"] >= 1 for d in destinos)


def test_resumen_de_ventas_devuelve_totales_coherentes():
    from services.reserva_service import ReservaService

    db = Database(URL)
    try:
        r = ReservaService(db).resumen_ventas()
    finally:
        db.cerrar()
    assert float(r["subtotal"]) + float(r["iva"]) == pytest.approx(float(r["total"]))
    assert r["reservas_confirmadas"] >= 0 and len(r["vuelos_top"]) <= 5
