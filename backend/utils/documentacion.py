"""Documentación OpenAPI (Swagger UI) de los contratos de servicio.

Cada endpoint tiene su contrato en `docs/swagger/<servicio>/<operacion>.yml` y la ruta
lo enlaza con `@swag_from(contrato("servicio", "operacion"))`: así los controladores
quedan cortos y la documentación vive aparte.
"""
from pathlib import Path

from flasgger import Swagger
from flask import Flask

CARPETA_CONTRATOS = Path(__file__).resolve().parent.parent / "docs" / "swagger"


def contrato(servicio: str, operacion: str) -> str:
    """Ruta del archivo .yml con el contrato Swagger de una operación."""
    ruta = CARPETA_CONTRATOS / servicio / f"{operacion}.yml"
    if not ruta.is_file():
        raise FileNotFoundError(f"No existe el contrato Swagger {ruta}")
    return str(ruta)

_TEMPLATE = {
    "info": {
        "title": "Kuntur EC · API de Reservas de Vuelos (SOA)",
        "description": "Servicios REST: usuarios, autenticación, vuelos y reservas.",
        "version": "1.0.0",
    },
    # Un tag por servicio SOA (proveedor); el consumidor es el cliente Flutter.
    "tags": [
        {"name": "Sistema", "description": "Estado del servicio y de la base de datos."},
        {"name": "Usuarios", "description": "Servicio de Usuarios: registro de clientes."},
        {"name": "Autenticación", "description": "Servicio de Autenticación: login/logout con JWT."},
        {"name": "Vuelos", "description": "Servicio de Vuelos: búsqueda, detalle y alta (admin)."},
        {"name": "Reservas", "description": "Servicio de Reservas: crear, consultar, modificar, cancelar y comprobante XML."},
    ],
    "definitions": {
        "Vuelo": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "example": 1},
                "codigo": {"type": "string", "example": "KT101"},
                "origen": {"type": "string", "example": "Quito"},
                "destino": {"type": "string", "example": "Guayaquil"},
                "fecha": {"type": "string", "format": "date", "example": "2026-12-01"},
                "hora_salida": {"type": "string", "example": "07:00:00"},
                "hora_llegada": {"type": "string", "example": "07:50:00"},
                "precio": {"type": "string", "example": "89.00", "description": "Monto con 2 decimales"},
                "capacidad": {"type": "integer", "example": 120},
                "asientos_disponibles": {"type": "integer", "example": 120},
                "version": {"type": "integer", "example": 1, "description": "Control de concurrencia"},
            },
        },
        "Reserva": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "example": 58},
                "usuario_id": {"type": "integer", "example": 2},
                "vuelo_id": {"type": "integer", "example": 1},
                "cantidad_asientos": {"type": "integer", "example": 2},
                "subtotal": {"type": "string", "example": "178.00"},
                "iva_porcentaje": {"type": "string", "example": "15.00"},
                "iva_valor": {"type": "string", "example": "26.70"},
                "total": {"type": "string", "example": "204.70"},
                "estado": {"type": "string", "enum": ["confirmada", "cancelada"]},
                "fecha_reserva": {"type": "string", "format": "date-time"},
                "version": {"type": "integer", "example": 1, "description": "Enviarla al modificar (PUT)"},
                "vuelo": {
                    "type": "object",
                    "description": "Resumen del vuelo reservado",
                    "properties": {
                        "codigo": {"type": "string", "example": "KT101"},
                        "origen": {"type": "string", "example": "Quito"},
                        "destino": {"type": "string", "example": "Guayaquil"},
                        "fecha": {"type": "string", "format": "date"},
                        "hora_salida": {"type": "string"},
                        "hora_llegada": {"type": "string"},
                    },
                },
            },
        },
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
