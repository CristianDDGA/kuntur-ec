"""Cerrado por defecto: toda ruta de la API declara si es pública o protegida."""
import pytest
from flask import Blueprint

from app import create_app
from config import Settings
from utils.autenticacion import publica


def test_todas_las_rutas_declaran_su_acceso(app):
    sin_declarar = [
        regla.endpoint
        for regla in app.url_map.iter_rules()
        if "." in regla.endpoint  # endpoints de blueprints propios (no static ni Swagger)
        and getattr(app.view_functions[regla.endpoint], "_acceso", None) is None
        and regla.endpoint.split(".")[0] in app.blueprints
        and not regla.endpoint.startswith(("flasgger.",))
    ]
    assert sin_declarar == []


def test_una_ruta_olvidada_no_queda_abierta():
    app = create_app(Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "x"}))
    olvidada = Blueprint("olvidada", __name__)

    @olvidada.get("/secreto")
    def secreto():
        return {"dato": "privado"}

    app.register_blueprint(olvidada, url_prefix="/api/olvidada")
    app.config["PROPAGATE_EXCEPTIONS"] = False
    respuesta = app.test_client().get("/api/olvidada/secreto")
    assert respuesta.status_code == 500
    assert b"privado" not in respuesta.data


def test_una_ruta_publica_declarada_responde():
    app = create_app(Settings.from_env({"APP_ENV": "testing", "JWT_SECRET_KEY": "x"}))
    abierta = Blueprint("abierta", __name__)

    @abierta.get("/ok")
    @publica
    def ok():
        return {"ok": True}

    app.register_blueprint(abierta, url_prefix="/api/abierta")
    assert app.test_client().get("/api/abierta/ok").status_code == 200
