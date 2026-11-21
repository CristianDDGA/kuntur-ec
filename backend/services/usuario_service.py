"""Servicio Usuarios: registro y consulta de usuarios."""
from __future__ import annotations

import re
import secrets
from typing import Protocol

from psycopg.errors import UniqueViolation

from database import Database
from models import Rol, Usuario
from utils.excepciones import ConflictError, ValidationError
from utils.google import IdentidadGoogle
from utils.limites import CONTRASENA as MAX_LARGO_CONTRASENA  # bcrypt además solo admite 72 bytes
from utils.limites import NOMBRE_PERSONA as MAX_LARGO_NOMBRE
from utils.seguridad import LIMITE_BYTES_BCRYPT, CifradorContrasenas
from utils.validaciones import cedula as validar_cedula
from utils.validaciones import correo as validar_correo
from utils.validaciones import nombre_propio, texto_obligatorio

MIN_LARGO_CONTRASENA = 8

_COLUMNAS = "id, nombre, correo, password_hash, rol, fecha_registro, cedula, correo_verificado, google_sub"


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
        cedula = validar_cedula(datos)
        contrasena = texto_obligatorio(datos, "password", MAX_LARGO_CONTRASENA, normalizar=False)
        validar_contrasena(contrasena)

        try:
            with self._db.transaccion() as cur:
                cur.execute(
                    f"INSERT INTO usuarios (nombre, correo, password_hash, rol, cedula, correo_verificado) "
                    f"VALUES (%s, %s, %s, %s, %s, FALSE) RETURNING {_COLUMNAS}",  # nace sin verificar
                    (nombre, correo, self._cifrador.cifrar(contrasena), Rol.CLIENTE.value, cedula),
                )
                return Usuario.from_row(cur.fetchone())
        except UniqueViolation as error:
            if getattr(error.diag, "constraint_name", None) == "ux_usuarios_cedula":
                raise ConflictError("Ya existe una cuenta registrada con esa cédula.") from None
            raise ConflictError("Ya existe una cuenta registrada con ese correo.") from None

    # ------------------------------------------------------------ Google

    def buscar_por_google_sub(self, sub: str) -> Usuario | None:
        with self._db.transaccion() as cur:
            cur.execute(f"SELECT {_COLUMNAS} FROM usuarios WHERE google_sub = %s", (sub,))
            fila = cur.fetchone()
        return Usuario.from_row(fila) if fila else None

    def vincular_google(self, usuario_id: int, sub: str) -> Usuario:
        """Une una cuenta existente con su cuenta de Google. Como Google ya comprobó que la persona es dueña del
        correo, la cuenta queda verificada (y un código pendiente deja de servir)."""
        with self._db.transaccion() as cur:
            cur.execute(
                "UPDATE usuarios SET google_sub = %s, correo_verificado = TRUE "
                f"WHERE id = %s AND (google_sub IS NULL OR google_sub = %s) RETURNING {_COLUMNAS}",
                (sub, usuario_id, sub),
            )
            fila = cur.fetchone()
            if fila is None:
                raise ConflictError("Esa cuenta ya está vinculada a otra cuenta de Google.")
            cur.execute("DELETE FROM codigos_verificacion WHERE usuario_id = %s", (usuario_id,))
        return Usuario.from_row(fila)

    def crear_desde_google(self, identidad: IdentidadGoogle) -> Usuario:
        """Cuenta nueva con los datos de Google: correo ya verificado, sin cédula (se pide después) y con una
        contraseña aleatoria que nadie conoce (se entra siempre con Google)."""
        nombre = " ".join(identidad.nombre.split())[:MAX_LARGO_NOMBRE] or identidad.correo.split("@")[0]
        try:
            with self._db.transaccion() as cur:
                cur.execute(
                    "INSERT INTO usuarios (nombre, correo, password_hash, rol, correo_verificado, google_sub) "
                    f"VALUES (%s, %s, %s, %s, TRUE, %s) RETURNING {_COLUMNAS}",
                    (nombre, identidad.correo, self._cifrador.cifrar(secrets.token_urlsafe(32)),
                     Rol.CLIENTE.value, identidad.sub),
                )
                return Usuario.from_row(cur.fetchone())
        except UniqueViolation:
            # Dos peticiones a la vez (o el correo ya existía): se devuelve la cuenta que ganó la carrera.
            existente = self.buscar_por_google_sub(identidad.sub) or self.buscar_por_correo(identidad.correo)
            if existente is None:
                raise
            return existente

    # ------------------------------------------------------------ cédula

    def completar_cedula(self, usuario_id: int, datos: dict) -> Usuario:
        """Guarda la cédula de una cuenta que no la tiene (p. ej. creada con Google). Una vez puesta no se cambia."""
        cedula = validar_cedula(datos)
        try:
            with self._db.transaccion() as cur:
                cur.execute(
                    f"UPDATE usuarios SET cedula = %s WHERE id = %s AND cedula IS NULL RETURNING {_COLUMNAS}",
                    (cedula, usuario_id),
                )
                fila = cur.fetchone()
        except UniqueViolation:
            raise ConflictError("Ya existe una cuenta registrada con esa cédula.") from None
        if fila is None:
            raise ConflictError("Su cédula ya está registrada y no se puede cambiar.")
        return Usuario.from_row(fila)

    def buscar_por_correo(self, correo: str) -> Usuario | None:
        with self._db.transaccion() as cur:
            cur.execute(
                f"SELECT {_COLUMNAS} FROM usuarios WHERE lower(correo) = lower(%s)",
                (correo.strip(),),
            )
            fila = cur.fetchone()
        return Usuario.from_row(fila) if fila else None
