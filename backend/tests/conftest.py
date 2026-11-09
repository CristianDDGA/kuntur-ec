import pytest

from src.infrastructure.config.settings import Settings
from src.presentation.api.app_factory import create_app


@pytest.fixture
def settings() -> Settings:
    return Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas"})


@pytest.fixture
def app(settings):
    return create_app(settings)


@pytest.fixture
def client(app):
    return app.test_client()
