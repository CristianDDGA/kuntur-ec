"""Conexión a la base de datos (Supabase / PostgreSQL) con un pool de conexiones.

Uso en los servicios (se inyecta por constructor):

    with db.transaccion() as cur:
        cur.execute("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
        fila = cur.fetchone()          # dict -> Vuelo.from_row(fila)

Cada `transaccion()` hace COMMIT al terminar sin errores y ROLLBACK si ocurre
una excepción, así una reserva nunca queda a medias.

Aplicar el esquema y los datos iniciales (desde backend/):

    python database.py
"""
from __future__ import annotations

import atexit
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from psycopg import Cursor
from psycopg.rows import DictRow, dict_row
from psycopg_pool import ConnectionPool

from config import ConfigurationError, Settings

CARPETA_SQL = Path(__file__).resolve().parent.parent / "database"
SCRIPTS_INICIALES = ("schema.sql", "seed.sql")


class Database:
    """Pool de conexiones. Se abre la primera vez que se usa (la app arranca aunque la BD no responda)."""

    def __init__(self, url: str, min_size: int = 1, max_size: int = 5):
        if not url:
            raise ConfigurationError("Falta DATABASE_URL en el archivo .env.")
        self._pool = ConnectionPool(
            url,
            min_size=min_size,
            max_size=max_size,
            open=False,
            # dict_row: cada fila llega como dict, listo para Modelo.from_row.
            # prepare_threshold=None: compatible con el pooler de Supabase.
            kwargs={"row_factory": dict_row, "prepare_threshold": None},
        )

    @classmethod
    def from_settings(cls, settings: Settings) -> "Database":
        return cls(settings.database_url)

    def _abrir(self) -> None:
        if self._pool.closed:
            self._pool.open(wait=True, timeout=10)
            # Cierra el pool al terminar el proceso (evita hilos colgados al salir).
            atexit.register(self.cerrar)

    @contextmanager
    def transaccion(self) -> Iterator[Cursor[DictRow]]:
        """Cursor dentro de una transacción: COMMIT al salir, ROLLBACK si hay error."""
        self._abrir()
        with self._pool.connection() as conexion, conexion.transaction(), conexion.cursor() as cur:
            yield cur

    def disponible(self) -> bool:
        """True si la BD responde (para el endpoint de salud)."""
        try:
            with self.transaccion() as cur:
                cur.execute("SELECT 1 AS ok")
                return cur.fetchone() == {"ok": 1}
        except Exception:  # noqa: BLE001 - cualquier fallo = no disponible
            return False

    def ejecutar_script(self, ruta: Path) -> None:
        """Ejecuta un archivo .sql completo (varias sentencias) en una transacción."""
        with self.transaccion() as cur:
            cur.execute(ruta.read_text(encoding="utf-8"))

    def cerrar(self) -> None:
        if not self._pool.closed:
            self._pool.close()


def aplicar_scripts_iniciales(db: Database) -> list[str]:
    """Crea las tablas y carga los datos iniciales. Es seguro repetirlo."""
    for nombre in SCRIPTS_INICIALES:
        db.ejecutar_script(CARPETA_SQL / nombre)
    return list(SCRIPTS_INICIALES)


if __name__ == "__main__":
    base = Database.from_settings(Settings.from_env())
    try:
        for script in aplicar_scripts_iniciales(base):
            print(f"Aplicado: database/{script}")
    finally:
        base.cerrar()
