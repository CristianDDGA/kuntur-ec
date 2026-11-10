"""Servicio Usuarios: registro y consulta de usuarios."""
from __future__ import annotations

import re
from typing import Protocol

from psycopg.errors import UniqueViolation

from database import Database
from models import Rol, Usuario
from utils.excepciones import ConflictError, ValidationError
from utils.seguridad import LIMITE_BYTES_BCRYPT, CifradorContrasenas

MIN_LARGO_CONTRASENA = 8
MAX_LARGO_NOMBRE = 100
MAX_LARGO_CORREO = 150
_CORREO = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

_COLUMNAS = "id, nombre, correo, password_hash, rol, fecha_registro"


class Cifrador(Protocol):
    def cifrar(self, contrasena: str) -> str: ...


def _texto(datos: dict, campo: str) -> str:
    valor = datos.get(campo)
    if not isinstance(valor, str) or not valor.strip():
        raise ValidationError(f"El campo '{campo}' es obligatorio.")
    return valor


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
        nombre = " ".join(_texto(datos, "nombre").split())
        correo = _texto(datos, "correo").strip().lower()
        contrasena = _texto(datos, "password")

        if len(nombre) > MAX_LARGO_NOMBRE:
            raise ValidationError(f"El nombre no puede superar {MAX_LARGO_NOMBRE} caracteres.")
        if len(correo) > MAX_LARGO_CORREO or not _CORREO.match(correo):
            raise ValidationError("El correo no es válido.")
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
