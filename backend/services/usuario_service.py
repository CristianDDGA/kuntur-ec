"""Servicio Usuarios: registro y consulta de usuarios."""
from __future__ import annotations

import re
from typing import Protocol

from psycopg.errors import UniqueViolation

from database import Database
from models import Rol, Usuario
from utils.excepciones import ConflictError, ValidationError
from utils.limites import CONTRASENA as MAX_LARGO_CONTRASENA  # bcrypt además solo admite 72 bytes
from utils.limites import NOMBRE_PERSONA as MAX_LARGO_NOMBRE
from utils.seguridad import LIMITE_BYTES_BCRYPT, CifradorContrasenas
from utils.validaciones import correo as validar_correo
from utils.validaciones import nombre_propio, texto_obligatorio

MIN_LARGO_CONTRASENA = 8

_COLUMNAS = "id, nombre, correo, password_hash, rol, fecha_registro"


class Cifrador(Protocol):
    def cifrar(self, contrasena: str) -> str: ...


def validar_contrasena(contrasena: str) -> None:
    if len(contrasena) < MIN_LARGO_CONTRASENA:
        raise ValidationError(f"La contraseña debe tener al menos {MIN_LARGO_CONTRASENA} caracteres.")
    if len(contrasena.encode("utf-8")) > LIMITE_BYTES_BCRYPT:
        raise ValidationError("La contraseña es demasiado larga.")
    if not (re.search(r"[A-Za-z]", contrasena) and re.search(r"\d", contrasena)):
        raise ValidationError("La contraseña debe combinar letras y números.")


class UsuarioService:
    def __init__(self, db: Database, cifrador: Cifrador | None = None):
        self._db = db
        self._cifrador = cifrador or CifradorContrasenas()

    def registrar(self, datos: dict) -> Usuario:
        """Crea un usuario con rol cliente. El rol nunca se toma de la petición."""
        nombre = nombre_propio(datos, "nombre", MAX_LARGO_NOMBRE)
        correo = validar_correo(datos)
        contrasena = texto_obligatorio(datos, "password", MAX_LARGO_CONTRASENA, normalizar=False)
        validar_contrasena(contrasena)

        try:
            with self._db.transaccion() as cur:
                cur.execute(
                    f"INSERT INTO usuarios (nombre, correo, password_hash, rol) "
                    f"VALUES (%s, %s, %s, %s) RETURNING {_COLUMNAS}",
                    (nombre, correo, self._cifrador.cifrar(contrasena), Rol.CLIENTE.value),
                )
                return Usuario.from_row(cur.fetchone())
        except UniqueViolation:
            raise ConflictError("Ya existe una cuenta registrada con ese correo.") from None

    def buscar_por_correo(self, correo: str) -> Usuario | None:
        with self._db.transaccion() as cur:
            cur.execute(
                f"SELECT {_COLUMNAS} FROM usuarios WHERE lower(correo) = lower(%s)",
                (correo.strip(),),
            )
            fila = cur.fetchone()
        return Usuario.from_row(fila) if fila else None
