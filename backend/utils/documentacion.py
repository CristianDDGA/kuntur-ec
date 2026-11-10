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
        "Bearer": {
            "type": "apiKey",
            "name": "Authorization",
            "in": "header",
            "description": "Escriba la palabra Bearer, un espacio y el token obtenido en /api/auth/login.",
        }
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
            # Sin esta clave flasgger 0.9.7.1 escribe `let auth_config = None;` en el
            # JavaScript de la página y Swagger UI falla (ReferenceError).
            "auth": {},
            # Conserva el token de "Authorize" al recargar la página.
            "ui_params": {"persistAuthorization": True},
        },
    )
