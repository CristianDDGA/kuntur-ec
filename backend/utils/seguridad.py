"""Cifrado de contraseñas con bcrypt.

Se usa bcrypt y no SHA256: bcrypt es lento a propósito y agrega una sal
aleatoria a cada contraseña, así dos usuarios con la misma clave tienen
hashes distintos y un ataque de fuerza bruta es mucho más costoso.
(La firma de JWT se agrega en la sección B4.)
"""
from __future__ import annotations

import bcrypt

# bcrypt solo considera los primeros 72 bytes; más largo se rechaza en la validación.
LIMITE_BYTES_BCRYPT = 72


class CifradorContrasenas:
    def __init__(self, costo: int = 12):
        # costo 12 ≈ 0,25 s por hash: aceptable al registrarse, caro para un atacante.
        # En las pruebas se usa 4 para que sean rápidas.
        self._costo = costo

    def cifrar(self, contrasena: str) -> str:
        return bcrypt.hashpw(contrasena.encode("utf-8"), bcrypt.gensalt(self._costo)).decode("ascii")

    def verificar(self, contrasena: str, hash_guardado: str) -> bool:
        try:
            return bcrypt.checkpw(contrasena.encode("utf-8"), hash_guardado.encode("ascii"))
        except ValueError:  # hash con formato inválido
            return False
