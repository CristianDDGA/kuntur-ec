import smtplib

import pytest

from utils.correo import EnviadorLocal, EnviadorSmtp
from utils.excepciones import ServiceUnavailableError


class SmtpFalso:
    instancias: list["SmtpFalso"] = []
    fallar_en: str | None = None

    def __init__(self, host, puerto, timeout=None):
        self.host, self.puerto, self.timeout = host, puerto, timeout
        self.pasos: list[str] = []
        self.mensaje = None
        SmtpFalso.instancias.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def _paso(self, nombre):
        self.pasos.append(nombre)
        if SmtpFalso.fallar_en == nombre:
            raise smtplib.SMTPAuthenticationError(535, b"clave secreta que no debe verse")

    def starttls(self, context=None):
        self._paso("starttls")
        assert context is not None  # se verifica el certificado del servidor

    def login(self, usuario, clave):
        self._paso("login")
        self.credenciales = (usuario, clave)

    def send_message(self, mensaje):
        self._paso("send")
        self.mensaje = mensaje


@pytest.fixture(autouse=True)
def smtp_falso(monkeypatch):
    SmtpFalso.instancias.clear()
    SmtpFalso.fallar_en = None
    monkeypatch.setattr(smtplib, "SMTP", SmtpFalso)


def _enviador():
    return EnviadorSmtp("smtp.gmail.com", 587, "yo@gmail.com", "clave-app", "Kuntur EC <yo@gmail.com>")


def test_envia_con_tls_inicio_de_sesion_y_los_encabezados_correctos():
    _enviador().enviar("ana@correo.com", "Su código", "Hola 123456", "<b>Hola 123456</b>")

    (smtp,) = SmtpFalso.instancias
    assert smtp.pasos == ["starttls", "login", "send"]  # TLS antes de mandar la clave
    assert smtp.credenciales == ("yo@gmail.com", "clave-app")
    assert (smtp.host, smtp.puerto) == ("smtp.gmail.com", 587) and smtp.timeout
    assert smtp.mensaje["To"] == "ana@correo.com" and smtp.mensaje["Subject"] == "Su código"
    assert smtp.mensaje["From"] == "Kuntur EC <yo@gmail.com>"
    assert smtp.mensaje.get_body(("plain",)).get_content().strip() == "Hola 123456"
    assert "<b>Hola 123456</b>" in smtp.mensaje.get_body(("html",)).get_content()


@pytest.mark.parametrize("paso", ["starttls", "login", "send"])
def test_un_fallo_del_servidor_de_correo_es_503_sin_filtrar_detalles(paso):
    SmtpFalso.fallar_en = paso
    with pytest.raises(ServiceUnavailableError) as e:
        _enviador().enviar("ana@correo.com", "x", "y")
    assert "clave" not in e.value.mensaje and "535" not in e.value.mensaje


def test_la_red_caida_tambien_es_503(monkeypatch):
    def sin_red(*a, **k):
        raise OSError("sin red")

    monkeypatch.setattr(smtplib, "SMTP", sin_red)
    with pytest.raises(ServiceUnavailableError):
        _enviador().enviar("ana@correo.com", "x", "y")


def test_el_enviador_local_solo_guarda_el_mensaje():
    local = EnviadorLocal()
    local.enviar("ana@correo.com", "Asunto", "Cuerpo")
    assert local.enviados == [("ana@correo.com", "Asunto", "Cuerpo")]
