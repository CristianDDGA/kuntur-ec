"""Configuración de la aplicación leída desde variables de entorno (.env).

Fuera de desarrollo y pruebas la aplicación NO arranca si faltan valores
sensibles: así nunca se usa en producción una clave JWT por defecto.
"""
from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass

from dotenv import load_dotenv

_ENTORNOS_LOCALES = frozenset({"development", "testing"})
_CLAVE_JWT_LOCAL = "clave-local-solo-para-desarrollo"
_OBLIGATORIAS_FUERA_DE_LOCAL = ("DATABASE_URL", "JWT_SECRET_KEY")


class ConfigurationError(RuntimeError):
    """La configuración del entorno es incompleta o inválida."""


@dataclass(frozen=True)
class Settings:
    app_env: str
    app_port: int
    database_url: str
    jwt_secret_key: str
    jwt_expires_minutes: int
    cors_origins: tuple[str, ...]

    @property
    def is_testing(self) -> bool:
        return self.app_env == "testing"

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "Settings":
        if env is None:
            load_dotenv()
            env = os.environ

        app_env = env.get("APP_ENV", "development")
        if app_env not in _ENTORNOS_LOCALES:
            faltantes = [k for k in _OBLIGATORIAS_FUERA_DE_LOCAL if not env.get(k)]
            if faltantes:
                raise ConfigurationError(
                    f"Faltan variables obligatorias para APP_ENV={app_env}: {', '.join(faltantes)}"
                )

        return cls(
            app_env=app_env,
            app_port=int(env.get("APP_PORT", "5000")),
            database_url=env.get("DATABASE_URL", ""),
            jwt_secret_key=env.get("JWT_SECRET_KEY") or _CLAVE_JWT_LOCAL,
            jwt_expires_minutes=int(env.get("JWT_EXPIRES_MINUTES", "60")),
            cors_origins=tuple(o.strip() for o in env.get("CORS_ORIGINS", "*").split(",")),
        )
