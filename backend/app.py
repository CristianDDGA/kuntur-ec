"""Kuntur EC · API REST (Flask).

Punto de entrada:
    python app.py                      (desarrollo)
    gunicorn "app:create_app()"        (producción)

`create_app` solo ensambla las piezas; cada una vive en su propio módulo.
"""
from __future__ import annotations

from flask import Flask
from flask_cors import CORS

from config import Settings
from database import Database
from routes.health_routes import health_bp
from routes.usuarios_routes import usuarios_bp
from services.usuario_service import UsuarioService
from utils.documentacion import init_docs
from utils.formatos import JsonFormato, XmlFormato
from utils.manejador_errores import register_error_handlers
from utils.respuestas import ContentNegotiator

API_PREFIX = "/api"


def create_app(settings: Settings | None = None, db: Database | None = None) -> Flask:
    settings = settings or Settings.from_env()
    if db is None and settings.database_url:
        db = Database.from_settings(settings)

    app = Flask(__name__)
    app.config["TESTING"] = settings.is_testing
    app.extensions["settings"] = settings
    app.extensions["db"] = db  # None si no hay DATABASE_URL (p. ej. en pruebas)
    # Servicios inyectados: las rutas los leen de app.extensions y las pruebas los reemplazan por fakes.
    app.extensions["usuario_service"] = UsuarioService(db) if db is not None else None

    ContentNegotiator(
        formatos=(JsonFormato(), XmlFormato()), default_mimetype=JsonFormato.mimetype
    ).init_app(app)
    CORS(app, resources={rf"{API_PREFIX}/*": {"origins": list(settings.cors_origins)}})
    init_docs(app, API_PREFIX)
    register_error_handlers(app)

    app.register_blueprint(health_bp, url_prefix=API_PREFIX)
    app.register_blueprint(usuarios_bp, url_prefix=f"{API_PREFIX}/usuarios")
    # Próximas secciones: auth_bp, vuelos_bp, reservas_bp

    return app


if __name__ == "__main__":
    settings = Settings.from_env()
    create_app(settings).run(host="0.0.0.0", port=settings.app_port, debug=settings.is_development)
