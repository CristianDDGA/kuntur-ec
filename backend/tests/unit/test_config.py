import pytest

from config import ConfigurationError, Settings


def test_en_desarrollo_usa_valores_locales():
    settings = Settings.from_env({"APP_ENV": "development"})
    assert settings.is_development
    assert settings.jwt_secret_key


def test_en_produccion_sin_secretos_no_arranca():
    with pytest.raises(ConfigurationError, match="DATABASE_URL, JWT_SECRET_KEY"):
        Settings.from_env({"APP_ENV": "production"})


def test_en_produccion_con_secretos_arranca():
    clave = "k" * 40
    settings = Settings.from_env(
        {"APP_ENV": "production", "DATABASE_URL": "postgresql://x", "JWT_SECRET_KEY": clave,
         "CORS_ORIGINS": "https://kuntur.ec", "SMTP_HOST": "smtp.gmail.com", "SMTP_USER": "a@b.com", "SMTP_PASSWORD": "x"}
    )
    assert settings.jwt_secret_key == clave
    assert settings.smtp_configurado


def test_en_produccion_rechaza_clave_jwt_corta():
    with pytest.raises(ConfigurationError, match="al menos 32"):
        Settings.from_env(
            {"APP_ENV": "production", "DATABASE_URL": "postgresql://x", "JWT_SECRET_KEY": "s3cr3t",
             "CORS_ORIGINS": "https://kuntur.ec", "SMTP_HOST": "smtp.gmail.com", "SMTP_USER": "a@b.com", "SMTP_PASSWORD": "x"}
        )


def test_en_produccion_rechaza_cors_comodin():
    with pytest.raises(ConfigurationError, match="CORS_ORIGINS"):
        Settings.from_env(
            {"APP_ENV": "production", "DATABASE_URL": "postgresql://x", "JWT_SECRET_KEY": "k" * 40, "SMTP_HOST": "smtp.gmail.com", "SMTP_USER": "a@b.com", "SMTP_PASSWORD": "x"}
        )


def test_en_produccion_sin_smtp_no_arranca():
    with pytest.raises(ConfigurationError, match="SMTP_HOST"):
        Settings.from_env(
            {"APP_ENV": "production", "DATABASE_URL": "postgresql://x", "JWT_SECRET_KEY": "k" * 40,
             "CORS_ORIGINS": "https://kuntur.ec"}
        )


def test_en_desarrollo_sin_smtp_se_permite_y_el_remitente_cae_al_usuario():
    assert not Settings.from_env({"APP_ENV": "development"}).smtp_configurado
    s = Settings.from_env({"APP_ENV": "development", "SMTP_HOST": "h", "SMTP_USER": "u@x.com", "SMTP_PASSWORD": "p"})
    assert s.smtp_configurado and s.smtp_from == "u@x.com" and s.smtp_port == 587


def test_cors_admite_varios_origenes():
    settings = Settings.from_env({"CORS_ORIGINS": "http://a.com, http://b.com"})
    assert settings.cors_origins == ("http://a.com", "http://b.com")
