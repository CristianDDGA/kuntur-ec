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
from routes.auth_routes import auth_bp
from routes.health_routes import health_bp
from routes.iva_routes import iva_bp
from routes.reservas_routes import reservas_bp
from routes.usuarios_routes import usuarios_bp
from routes.vuelos_routes import vuelos_bp
from services.auth_service import AuthService
from services.iva_service import IvaService
from services.reserva_service import ReservaService
from services.usuario_service import UsuarioService
from services.vuelo_service import VueloService
from utils.convertidores import IdConverter
from utils.documentacion import init_docs
from utils.formatos import JsonFormato, XmlFormato
from utils.manejador_errores import register_error_handlers
from utils.respuestas import ContentNegotiator
from utils.seguridad import EmisorTokens

API_PREFIX = "/api"
MAX_BYTES_CUERPO = 64 * 1024  # los cuerpos reales pesan menos de 1 KB: lo demás es abuso (413)


def _agregar_cabeceras_seguras(app: Flask) -> None:
    @app.after_request
    def cabeceras(respuesta):
        # El navegador no debe "adivinar" otro tipo de contenido distinto al declarado.
        respuesta.headers.setdefault("X-Content-Type-Options", "nosniff")
        # Los datos de la API (reservas, facturas, sesión) no deben quedar en cachés compartidas.
        if respuesta.mimetype in (JsonFormato.mimetype, XmlFormato.mimetype):
            respuesta.headers.setdefault("Cache-Control", "no-store")
        return respuesta


def _registrar_servicios(app: Flask, settings: Settings, db: Database | None) -> None:
    """Servicios inyectados: las rutas los leen de app.extensions y las pruebas los reemplazan por fakes."""
    if db is None:
        app.extensions.update(usuario_service=None, auth_service=None, vuelo_service=None, reserva_service=None, iva_service=None)
        return
    usuarios = UsuarioService(db)
    app.extensions["vuelo_service"] = VueloService(db)
    app.extensions["reserva_service"] = ReservaService(db)
    app.extensions["iva_service"] = IvaService(db)
    app.extensions["usuario_service"] = usuarios
    app.extensions["auth_service"] = AuthService(
        db, usuarios, EmisorTokens(settings.jwt_secret_key, settings.jwt_expires_minutes)
    )


def create_app(settings: Settings | None = None, db: Database | None = None) -> Flask:
    settings = settings or Settings.from_env()
    if db is None and settings.database_url:
        db = Database.from_settings(settings)

    app = Flask(__name__)
    app.config["TESTING"] = settings.is_testing
    app.config["MAX_CONTENT_LENGTH"] = MAX_BYTES_CUERPO
    app.url_map.converters["id"] = IdConverter  # <id:reserva_id>: entero positivo que cabe en la BD
    app.extensions["settings"] = settings
    app.extensions["db"] = db  # None si no hay DATABASE_URL (p. ej. en pruebas)
    _registrar_servicios(app, settings, db)

    ContentNegotiator(
        formatos=(JsonFormato(), XmlFormato()), default_mimetype=JsonFormato.mimetype
    ).init_app(app)
    CORS(app, resources={rf"{API_PREFIX}/*": {"origins": list(settings.cors_origins)}})
    init_docs(app, API_PREFIX)
    register_error_handlers(app)
    _agregar_cabeceras_seguras(app)

    app.register_blueprint(health_bp, url_prefix=API_PREFIX)
    app.register_blueprint(usuarios_bp, url_prefix=f"{API_PREFIX}/usuarios")
    app.register_blueprint(auth_bp, url_prefix=f"{API_PREFIX}/auth")
    app.register_blueprint(vuelos_bp, url_prefix=f"{API_PREFIX}/vuelos")
    app.register_blueprint(iva_bp, url_prefix=f"{API_PREFIX}/iva")
    app.register_blueprint(reservas_bp, url_prefix=f"{API_PREFIX}/reservas")

    return app


if __name__ == "__main__":
    settings = Settings.from_env()
    create_app(settings).run(host="0.0.0.0", port=settings.app_port, debug=settings.is_development)
