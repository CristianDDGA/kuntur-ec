"""Fábrica de la aplicación Flask (capa de presentación).

Solo ensambla piezas; cada una vive en su propio módulo.
"""
from __future__ import annotations

from flask import Flask
from flask_cors import CORS

from src.container import Container
from src.infrastructure.config.settings import Settings

from .docs import init_docs
from .error_handlers import register_error_handlers
from .responses import ContentNegotiator
from .routes.health_routes import health_bp
from .serializers.json_serializer import JsonSerializer
from .serializers.xml_serializer import XmlSerializer

API_PREFIX = "/api"


def create_app(settings: Settings | None = None) -> Flask:
    settings = settings or Settings.from_env()

    app = Flask(__name__)
    app.config["TESTING"] = settings.is_testing
    app.extensions["container"] = Container.build(settings)

    ContentNegotiator(
        serializers=(JsonSerializer(), XmlSerializer()),
        default_mimetype=JsonSerializer.mimetype,
    ).init_app(app)
    CORS(app, resources={rf"{API_PREFIX}/*": {"origins": list(settings.cors_origins)}})
    init_docs(app, API_PREFIX)
    register_error_handlers(app)

    app.register_blueprint(health_bp, url_prefix=API_PREFIX)
    # Próximas secciones: usuarios_bp, auth_bp, vuelos_bp, reservas_bp

    return app
