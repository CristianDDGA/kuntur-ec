"""Servicio Aviones: se cargan con un CSV (previsualizar y luego importar); el administrador los lista para crear vuelos."""
from __future__ import annotations

from typing import Any

from database import Database
from models import Avion
from utils.asientos import COLUMNAS
from utils.excepciones import ValidationError
from utils.importacion_csv import ResultadoCsv, leer_aviones

_COLUMNAS = "id, matricula, modelo, filas"
_VISTA_PREVIA = 50  # filas que se muestran al previsualizar


class AvionService:
    def __init__(self, db: Database):
        self._db = db

    def listar(self) -> list[Avion]:
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM aviones ORDER BY matricula")
            return [Avion.from_row(f) for f in cur.fetchall()]

    def obtener(self, avion_id: int) -> Avion | None:
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM aviones WHERE id = %s", (avion_id,))
            fila = cur.fetchone()
        return Avion.from_row(fila) if fila else None

    @staticmethod
    def _ya_registradas(cur, resultado: ResultadoCsv) -> set[str]:
        cur.execute(
            "SELECT matricula FROM aviones WHERE matricula = ANY(%s)", ([f.matricula for f in resultado.validas],)
        )
        return {f["matricula"] for f in cur.fetchall()}

    @staticmethod
    def _resumen(resultado: ResultadoCsv, existentes: set[str]) -> dict[str, Any]:
        nuevos = [f for f in resultado.validas if f.matricula not in existentes]
        return {
            "total_filas": resultado.total_filas,
            "nuevos": len(nuevos),
            "existentes": sorted(existentes),
            "con_errores": len({e["linea"] for e in resultado.errores}),
            "errores": resultado.errores,
            "vista_previa": [
                {
                    "linea": f.linea,
                    "matricula": f.matricula,
                    "modelo": f.modelo,
                    "filas": f.filas,
                    "capacidad": f.filas * len(COLUMNAS),
                    "ya_existe": f.matricula in existentes,
                }
                for f in resultado.validas[:_VISTA_PREVIA]
            ],
        }

    def validar(self, contenido: bytes) -> dict[str, Any]:
        """Revisa el archivo sin guardar nada: qué se importaría y qué errores tiene."""
        resultado = leer_aviones(contenido)
        with self._db.transaccion() as cur:
            existentes = self._ya_registradas(cur, resultado) if resultado.validas else set()
        return self._resumen(resultado, existentes)

    def importar(self, contenido: bytes) -> dict[str, Any]:
        """Todo o nada: si alguna fila tiene errores no se guarda ninguna. Las matrículas ya registradas se omiten."""
        resultado = leer_aviones(contenido)
        if resultado.errores:
            raise ValidationError(
                "El archivo tiene filas con errores: corríjalo y vuelva a subirlo. No se importó ningún avión.",
                errores=resultado.errores,
            )
        if not resultado.validas:
            raise ValidationError("El archivo no tiene aviones para importar.")
        with self._db.transaccion() as cur:  # una sola transacción: o entran todos o ninguno
            existentes = self._ya_registradas(cur, resultado)
            nuevos = [f for f in resultado.validas if f.matricula not in existentes]
            if nuevos:
                cur.executemany(
                    "INSERT INTO aviones (matricula, modelo, filas) VALUES (%s, %s, %s) "
                    "ON CONFLICT (matricula) DO NOTHING",
                    [(f.matricula, f.modelo, f.filas) for f in nuevos],
                )
        return {"creados": len(nuevos), "omitidos": sorted(existentes), "total_filas": resultado.total_filas}
