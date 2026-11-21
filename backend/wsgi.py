"""Punto de entrada de producción: `gunicorn wsgi:app` (lo usa Render)."""
from app import create_app

app = create_app()
