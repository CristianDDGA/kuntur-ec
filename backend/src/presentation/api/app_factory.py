"""Fábrica de la aplicación Flask (capa de presentación)."""
from __future__ import annotations

from flasgger import Swagger
from flask import Flask
from flask_cors import CORS

from src.container import Container
from src.infrastructure.config.settings import Settings

from .error_handlers import register_error_handlers
from .routes.health_routes import health_bp

API_PREFIX = "/api"

SWAGGER_TEMPLATE = {
    "info": {
        "title": "Kuntur EC · API de Reservas de Vuelos (SOA)",
        "description": "Servicios REST: usuarios, autenticación, vuelos y reservas.",
        "version": "1.0.0",
    },
    "securityDefinitions": {
        "Bearer": {"type": "apiKey", "name": "Authorization", "in": "header"}
    },
}


def create_app(settings: Settings | None = None) -> Flask:
    settings = settings or Settings.from_env()
    container = Container.build(settings)

    app = Flask(__name__)
    app.config["TESTING"] = settings.is_testing
    app.extensions["container"] = container

    CORS(app, resources={rf"{API_PREFIX}/*": {"origins": settings.cors_origins}})
    Swagger(
        app,
        template=SWAGGER_TEMPLATE,
        config={
            "headers": [],
            "specs": [{"endpoint": "apispec", "route": f"{API_PREFIX}/apispec.json"}],
            "static_url_path": "/flasgger_static",
            "swagger_ui": True,
            "specs_route": f"{API_PREFIX}/docs/",
        },
    )

    register_error_handlers(app)
    app.register_blueprint(health_bp, url_prefix=API_PREFIX)
    # Próximas secciones: usuarios_bp, auth_bp, vuelos_bp, reservas_bp

    return app
