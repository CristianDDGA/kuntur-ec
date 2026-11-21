"""Tabla `usuarios`."""
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import ClassVar

from models.base import Modelo, requerir, texto_presente
from utils.validaciones import es_cedula, es_correo


class Rol(StrEnum):
    CLIENTE = "cliente"
    ADMIN = "admin"


@dataclass(frozen=True)
class Usuario(Modelo):
    id: int | None
    nombre: str
    correo: str
    password_hash: str
    rol: Rol
    fecha_registro: datetime | None
    cedula: str | None = None  # None en cuentas anteriores a pedirla (p. ej. el administrador)
    correo_verificado: bool = True  # False hasta que confirma el código enviado a su correo
    google_sub: str | None = None  # cuenta de Google vinculada (nunca se envía al cliente)

    # Nunca se envía al cliente.
    CAMPOS_PRIVADOS: ClassVar[frozenset[str]] = frozenset({"password_hash", "google_sub"})

    @property
    def es_admin(self) -> bool:
        return self.rol is Rol.ADMIN

    def _validar(self) -> None:
        requerir(texto_presente(self.nombre), "El nombre es obligatorio.")
        requerir(es_correo(self.correo or ""), "El correo no es válido.")
        requerir(texto_presente(self.password_hash), "La contraseña cifrada es obligatoria.")
        requerir(isinstance(self.rol, Rol), "El rol no es válido.")
        requerir(self.cedula is None or es_cedula(self.cedula), "La cédula no es válida.")
