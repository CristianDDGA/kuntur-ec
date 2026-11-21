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
_OBLIGATORIAS_FUERA_DE_LOCAL = ("DATABASE_URL", "JWT_SECRET_KEY", "SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD")
_MIN_CARACTERES_CLAVE_JWT = 32


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
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    google_client_id: str = ""  # ID de cliente OAuth web; vacío = el inicio con Google está desactivado

    @property
    def smtp_configurado(self) -> bool:
        return bool(self.smtp_host and self.smtp_user and self.smtp_password)

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

            clave = env.get("JWT_SECRET_KEY", "")
            if len(clave) < _MIN_CARACTERES_CLAVE_JWT:
                raise ConfigurationError(
                    f"JWT_SECRET_KEY debe tener al menos {_MIN_CARACTERES_CLAVE_JWT} caracteres fuera de desarrollo."
                )
            if "*" in (o.strip() for o in env.get("CORS_ORIGINS", "*").split(",")):
                raise ConfigurationError(
                    "CORS_ORIGINS no puede ser '*' fuera de desarrollo: liste los orígenes del frontend."
                )

        return cls(
            app_env=app_env,
            app_port=int(env.get("APP_PORT", "5000")),
            database_url=env.get("DATABASE_URL", ""),
            jwt_secret_key=env.get("JWT_SECRET_KEY") or _CLAVE_JWT_LOCAL,
            jwt_expires_minutes=int(env.get("JWT_EXPIRES_MINUTES", "60")),
            cors_origins=tuple(o.strip() for o in env.get("CORS_ORIGINS", "*").split(",")),
            smtp_host=env.get("SMTP_HOST", ""),
            smtp_port=int(env.get("SMTP_PORT", "587")),
            smtp_user=env.get("SMTP_USER", ""),
            smtp_password=env.get("SMTP_PASSWORD", ""),
            smtp_from=env.get("SMTP_FROM") or env.get("SMTP_USER", ""),
            google_client_id=env.get("GOOGLE_CLIENT_ID", "").strip(),
        )
