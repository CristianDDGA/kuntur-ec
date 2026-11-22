"""Límite de intentos fallidos (protección contra adivinar contraseñas por fuerza bruta).

Cuenta los fallos por clave (IP + correo) en una ventana de tiempo. Pasado el máximo
se responde 429 con la cabecera Retry-After hasta que venza la ventana.

Alcance: la memoria es de cada proceso. Con varios servidores detrás de un balanceador el
límite efectivo es por servidor; para un despliegue grande se reemplazaría por Redis o una tabla.
"""
from __future__ import annotations

import math
import threading
import time
from collections import deque
from collections.abc import Callable

from utils.excepciones import TooManyRequestsError


class LimitadorIntentos:
    def __init__(
        self,
        maximo: int = 5,
        ventana_segundos: int = 900,
        reloj: Callable[[], float] = time.monotonic,
        capacidad: int = 10_000,
    ):
        self._maximo = maximo
        self._ventana = ventana_segundos
        self._reloj = reloj
        self._capacidad = capacidad
        self._fallos: dict[str, deque[float]] = {}
        self._bloqueo = threading.Lock()

    def _vigentes(self, clave: str, ahora: float) -> deque[float]:
        fallos = self._fallos.get(clave)
        if fallos is None:
            return deque()
        while fallos and ahora - fallos[0] >= self._ventana:
            fallos.popleft()
        if not fallos:
            del self._fallos[clave]
        return fallos

    def verificar(self, clave: str) -> None:
        """Lanza TooManyRequestsError si la clave ya agotó sus intentos."""
        with self._bloqueo:
            ahora = self._reloj()
            fallos = self._vigentes(clave, ahora)
            if len(fallos) >= self._maximo:
                espera = max(1, math.ceil(self._ventana - (ahora - fallos[0])))
                raise TooManyRequestsError(
                    "Demasiados intentos fallidos. Espere antes de volver a intentarlo.",
                    reintentar_en_segundos=espera,
                )

    def registrar_fallo(self, clave: str) -> None:
        with self._bloqueo:
            ahora = self._reloj()
            if len(self._fallos) >= self._capacidad:  # evita crecer sin límite si alguien inunda claves
                for existente in list(self._fallos):
                    self._vigentes(existente, ahora)
                while len(self._fallos) >= self._capacidad:
                    self._fallos.pop(next(iter(self._fallos)))
            self._fallos.setdefault(clave, deque()).append(ahora)

    def limpiar(self, clave: str) -> None:
        with self._bloqueo:
            self._fallos.pop(clave, None)
