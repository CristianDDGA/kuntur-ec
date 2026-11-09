"""Configuración de la aplicación leída desde variables de entorno (.env)."""
from __future__ import annotations

import os
from dataclasses import dataclass
from decimal import Decimal

from dotenv import load_dotenv


@dataclass(frozen=True)
class Settings:
    app_env: str
    app_port: int
    database_url: str
    jwt_secret_key: str
    jwt_expires_minutes: int
    cors_origins: list[str]
    iva_porcentaje: Decimal

    @property
    def is_testing(self) -> bool:
        return self.app_env == "testing"

    @classmethod
    def from_env(cls) -> "Settings":
        load_dotenv()
        return cls(
            app_env=os.getenv("APP_ENV", "development"),
            app_port=int(os.getenv("APP_PORT", "5000")),
            database_url=os.getenv("DATABASE_URL", ""),
            jwt_secret_key=os.getenv("JWT_SECRET_KEY", "dev-secret-no-usar-en-produccion"),
            jwt_expires_minutes=int(os.getenv("JWT_EXPIRES_MINUTES", "60")),
            cors_origins=[o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",")],
            iva_porcentaje=Decimal(os.getenv("IVA_PORCENTAJE", "15")),
        )
