"""Punto de entrada para desarrollo: python run.py"""
from src.infrastructure.config.settings import Settings
from src.presentation.api.app_factory import create_app

settings = Settings.from_env()
app = create_app(settings)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=settings.app_port, debug=settings.app_env == "development")
