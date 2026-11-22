"""Conexión a la base de datos (Supabase / PostgreSQL) con un pool de conexiones.

Uso en los servicios (se inyecta por constructor):

    with db.transaccion() as cur:
        cur.execute("SELECT * FROM vuelos WHERE id = %s", (vuelo_id,))
        fila = cur.fetchone()          # dict -> Vuelo.from_row(fila)

Cada `transaccion()` hace COMMIT al terminar sin errores y ROLLBACK si ocurre
una excepción, así una reserva nunca queda a medias.

Si la base no responde, `transaccion()` falla rápido (unos segundos) con
ServiceUnavailableError (HTTP 503) en vez de dejar la petición colgada, y el pool
sigue reintentando conectarse en segundo plano: cuando la base vuelve, la API se
recupera sola, sin reiniciar el servidor.

Aplicar el esquema y los datos iniciales (desde backend/):

    python database.py
"""
from __future__ import annotations

import atexit
import logging
import threading
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from psycopg import Connection, Cursor, InterfaceError, OperationalError
from psycopg.rows import DictRow, dict_row
from psycopg_pool import ConnectionPool, PoolTimeout

from config import ConfigurationError, Settings
from utils.excepciones import ServiceUnavailableError

logger = logging.getLogger(__name__)

CARPETA_SQL = Path(__file__).resolve().parent.parent / "database"
SCRIPTS_INICIALES = ("schema.sql", "seed.sql")

ESPERA_CONEXION_SEGUNDOS = 5.0      # cuánto espera una petición por una conexión libre
TIEMPO_CONEXION_SEGUNDOS = 5        # cuánto tarda como máximo en abrirse una conexión nueva
TIEMPO_MAXIMO_CONSULTA_MS = 10_000  # PostgreSQL cancela consultas que superen este tiempo
REINTENTO_SEGUNDOS = 5


class Database:
    """Pool de conexiones. Se abre la primera vez que se usa (la app arranca aunque la BD no responda)."""

    def __init__(
        self,
        url: str,
        min_size: int = 1,
        max_size: int = 5,
        espera_conexion: float = ESPERA_CONEXION_SEGUNDOS,
    ):
        if not url:
            raise ConfigurationError("Falta DATABASE_URL en el archivo .env.")
        self._espera = espera_conexion
        self._bloqueo = threading.Lock()
        self._pool = ConnectionPool(
            url,
            min_size=min_size,
            max_size=max_size,
            open=False,
            # dict_row: cada fila llega como dict, listo para Modelo.from_row.
            # prepare_threshold=None: compatible con el pooler de Supabase.
            kwargs={
                "row_factory": dict_row,
                "prepare_threshold": None,
                "connect_timeout": TIEMPO_CONEXION_SEGUNDOS,
            },
            configure=self._configurar,
            name="kuntur-db",
        )

    @classmethod
    def from_settings(cls, settings: Settings) -> "Database":
        return cls(settings.database_url)

    @staticmethod
    def _configurar(conexion: Connection) -> None:
        """Se ejecuta en cada conexión nueva: ninguna consulta puede quedarse colgada para siempre."""
        conexion.execute(f"SET statement_timeout = {TIEMPO_MAXIMO_CONSULTA_MS}")
        conexion.commit()

    def _abrir(self) -> None:
        if self._pool.closed:
            with self._bloqueo:
                if self._pool.closed:
                    # wait=False: no bloquea si la BD está caída; las conexiones se crean (y se
                    # reintentan) en segundo plano y cada petición espera como máximo `espera`.
                    self._pool.open(wait=False)
                    # Cierra el pool al terminar el proceso (evita hilos colgados al salir).
                    atexit.register(self.cerrar)

    @contextmanager
    def transaccion(self) -> Iterator[Cursor[DictRow]]:
        """Cursor dentro de una transacción: COMMIT al salir, ROLLBACK si hay error."""
        self._abrir()
        try:
            with self._pool.connection(timeout=self._espera) as conexion:
                with conexion.transaction(), conexion.cursor() as cur:
                    yield cur
        except (PoolTimeout, OperationalError, InterfaceError) as error:
            logger.error("Base de datos no disponible (%s)", type(error).__name__)
            raise ServiceUnavailableError(
                "El servicio no está disponible temporalmente. Intente nuevamente en unos segundos.",
                reintentar_en_segundos=REINTENTO_SEGUNDOS,
            ) from None

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

    def cerrar(self, espera: float = 5.0) -> None:
        if not self._pool.closed:
            self._pool.close(timeout=espera)


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
