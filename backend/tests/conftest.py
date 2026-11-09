from decimal import Decimal

import pytest

from src.infrastructure.config.settings import Settings
from src.presentation.api.app_factory import create_app


@pytest.fixture
def settings() -> Settings:
    return Settings(
        app_env="testing",
        app_port=5000,
        database_url="",
        jwt_secret_key="clave-de-pruebas",
        jwt_expires_minutes=5,
        cors_origins=["*"],
        iva_porcentaje=Decimal("15"),
    )


@pytest.fixture
def client(settings):
    return create_app(settings).test_client()
