"""Dobles de prueba: reemplazan la BD real en las pruebas unitarias."""
from contextlib import contextmanager
from typing import Any


class CursorFalso:
    def __init__(self, filas: list[dict[str, Any] | None], error: Exception | None):
        self._filas = list(filas)
        self._error = error
        self.consultas: list[tuple[str, tuple]] = []
        self.rowcount = 0

    def execute(self, sql: str, params: tuple = ()) -> None:
        self.consultas.append((sql, params))
        if self._error:
            raise self._error

    def fetchall(self) -> list[dict[str, Any]]:
        filas, self._filas = [f for f in self._filas if f is not None], []
        return filas

    def fetchone(self) -> dict[str, Any] | None:
        return self._filas.pop(0) if self._filas else None


class BaseDatosFalsa:
    """Devuelve las `filas` indicadas en orden o lanza `error` al ejecutar SQL."""

    def __init__(self, filas: list[dict[str, Any] | None] | None = None, error: Exception | None = None):
        self.cursor = CursorFalso(filas or [], error)

    @contextmanager
    def transaccion(self):
        yield self.cursor


class CifradorFalso:
    def cifrar(self, contrasena: str) -> str:
        return f"hash::{contrasena}"
