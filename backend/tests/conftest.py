import pytest

from app import create_app
from config import Settings


@pytest.fixture
def settings() -> Settings:
    return Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "clave-de-pruebas"})


@pytest.fixture
def app(settings):
    return create_app(settings)


@pytest.fixture
def client(app):
    return app.test_client()
