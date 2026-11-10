"""Documentación OpenAPI (Swagger UI) de los contratos de servicio."""
from flasgger import Swagger
from flask import Flask

_TEMPLATE = {
    "info": {
        "title": "Kuntur EC · API de Reservas de Vuelos (SOA)",
        "description": "Servicios REST: usuarios, autenticación, vuelos y reservas.",
        "version": "1.0.0",
    },
    "securityDefinitions": {
        "Bearer": {"type": "apiKey", "name": "Authorization", "in": "header"}
    },
}


def init_docs(app: Flask, api_prefix: str) -> None:
    Swagger(
        app,
        template=_TEMPLATE,
        config={
            "headers": [],
            "specs": [{"endpoint": "apispec", "route": f"{api_prefix}/apispec.json"}],
            "static_url_path": "/flasgger_static",
            "swagger_ui": True,
            "specs_route": f"{api_prefix}/docs/",
        },
    )
