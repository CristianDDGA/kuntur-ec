import pytest
from google.auth import exceptions as errores_google
from google.oauth2 import id_token

from services.auth_service import AuthService
from tests.factories import un_usuario
from tests.fakes import BaseDatosFalsa
from utils.excepciones import ConflictError, ServiceUnavailableError, UnauthorizedError, ValidationError
from utils.google import IdentidadGoogle, VerificadorGoogleReal
from utils.seguridad import CifradorContrasenas, EmisorTokens

CLIENT_ID = "123-abc.apps.googleusercontent.com"
emisor = EmisorTokens("clave-de-pruebas-suficientemente-larga-32b", 60)


# ---------------------------------------------------------------- verificador del token de Google


def _verificador(monkeypatch, respuesta=None, error=None):
    llamadas = []

    def falso(token, peticion, audience):
        llamadas.append((token, audience))
        if error:
            raise error
        return respuesta

    monkeypatch.setattr(id_token, "verify_oauth2_token", falso)
    return VerificadorGoogleReal(CLIENT_ID), llamadas


def test_un_token_valido_devuelve_la_identidad_y_se_valida_contra_nuestro_client_id(monkeypatch):
    v, llamadas = _verificador(monkeypatch, {"sub": "1234", "email": " Ana@Gmail.COM ", "email_verified": True, "name": "  Ana   Torres "})
    assert v.verificar("jwt") == IdentidadGoogle(sub="1234", correo="ana@gmail.com", nombre="Ana Torres")
    assert llamadas == [("jwt", CLIENT_ID)]  # el audience es NUESTRO ID: un token de otra app no sirve


def test_sin_nombre_usa_la_parte_local_del_correo(monkeypatch):
    v, _ = _verificador(monkeypatch, {"sub": "1", "email": "ana.torres@gmail.com", "email_verified": True})
    assert v.verificar("jwt").nombre == "ana.torres"


@pytest.mark.parametrize(
    "datos",
    [
        {"sub": "1", "email": "a@gmail.com", "email_verified": False},
        {"sub": "1", "email": "a@gmail.com"},                              # sin el dato
        {"sub": "1", "email": "a@gmail.com", "email_verified": "true"},    # solo vale el booleano true
        {"sub": "1", "email": "", "email_verified": True},
        {"email": "a@gmail.com", "email_verified": True},                  # sin sub
    ],
)
def test_sin_correo_verificado_por_google_se_rechaza(monkeypatch, datos):
    v, _ = _verificador(monkeypatch, datos)
    with pytest.raises(UnauthorizedError, match="correo verificado"):
        v.verificar("jwt")


def test_firma_vencimiento_o_destinatario_incorrectos_son_401_sin_detalles(monkeypatch):
    v, _ = _verificador(monkeypatch, error=ValueError("Token expired: detalle interno de la librería"))
    with pytest.raises(UnauthorizedError) as e:
        v.verificar("jwt")
    assert "expired" not in e.value.mensaje.lower()


def test_si_no_se_puede_contactar_a_google_es_503(monkeypatch):
    v, _ = _verificador(monkeypatch, error=errores_google.TransportError("sin red"))
    with pytest.raises(ServiceUnavailableError):
        v.verificar("jwt")


# ---------------------------------------------------------------- AuthService.login_google


class VerificadorFalso:
    def __init__(self, identidad=None, error=None):
        self.identidad = identidad or IdentidadGoogle(sub="g-1", correo="ana@gmail.com", nombre="Ana Torres")
        self.error = error
        self.recibido = []

    def verificar(self, token):
        self.recibido.append(token)
        if self.error:
            raise self.error
        return self.identidad


class UsuariosFalsos:
    def __init__(self, por_sub=None, por_correo=None):
        self.por_sub, self.por_correo = por_sub, por_correo
        self.llamadas: list[tuple] = []

    def buscar_por_google_sub(self, sub):
        self.llamadas.append(("sub", sub))
        return self.por_sub

    def buscar_por_correo(self, correo):
        self.llamadas.append(("correo", correo))
        return self.por_correo

    def vincular_google(self, usuario_id, sub):
        self.llamadas.append(("vincular", usuario_id, sub))
        return un_usuario(id=usuario_id, google_sub=sub)

    def crear_desde_google(self, identidad):
        self.llamadas.append(("crear", identidad.correo))
        return un_usuario(id=99, correo=identidad.correo, nombre=identidad.nombre, cedula=None, google_sub=identidad.sub)


def _auth(usuarios, verificador="por-defecto", db=None):
    verificador = VerificadorFalso() if verificador == "por-defecto" else verificador
    return AuthService(db or BaseDatosFalsa(), usuarios, emisor, CifradorContrasenas(costo=4), verificador_google=verificador), verificador


def test_cuenta_ya_vinculada_inicia_sesion_sin_crear_ni_vincular():
    usuarios = UsuariosFalsos(por_sub=un_usuario(id=5))
    db = BaseDatosFalsa()
    auth, _ = _auth(usuarios, db=db)
    r = auth.login_google({"id_token": " token "})
    assert r["nuevo"] is False and r["tipo"] == "Bearer" and emisor.leer(r["token"]).usuario_id == 5
    assert [l[0] for l in usuarios.llamadas] == ["sub"]
    assert "INSERT INTO tokens" in db.cursor.consultas[0][0]  # misma sesión revocable que el login normal
    assert "google_sub" not in r["usuario"] and "password_hash" not in r["usuario"]  # nunca se envían


def test_una_cuenta_con_ese_correo_se_vincula_y_no_se_duplica():
    usuarios = UsuariosFalsos(por_correo=un_usuario(id=7, correo="ana@gmail.com"))
    auth, _ = _auth(usuarios)
    r = auth.login_google({"id_token": "t"})
    assert r["nuevo"] is False
    assert ("vincular", 7, "g-1") in usuarios.llamadas and not any(l[0] == "crear" for l in usuarios.llamadas)


def test_sin_cuenta_se_crea_una_nueva():
    usuarios = UsuariosFalsos()
    auth, _ = _auth(usuarios)
    r = auth.login_google({"id_token": "t"})
    assert r["nuevo"] is True and r["usuario"]["correo"] == "ana@gmail.com" and r["usuario"]["cedula"] is None
    assert ("crear", "ana@gmail.com") in usuarios.llamadas


def test_el_servidor_usa_solo_lo_que_firma_google_no_lo_que_envie_el_cliente():
    usuarios = UsuariosFalsos()
    auth, _ = _auth(usuarios)
    auth.login_google({"id_token": "t", "correo": "admin@kuntur.ec", "email": "admin@kuntur.ec", "rol": "admin", "nombre": "x"})
    assert ("correo", "ana@gmail.com") in usuarios.llamadas  # el de Google, no el del cuerpo
    assert not any("admin" in str(l) for l in usuarios.llamadas)


@pytest.mark.parametrize("cuerpo", [{}, {"id_token": None}, {"id_token": ""}, {"id_token": "   "}, {"id_token": 123}, {"id_token": ["x"]}])
def test_el_id_token_es_obligatorio_y_texto(cuerpo):
    usuarios = UsuariosFalsos()
    auth, verificador = _auth(usuarios)
    with pytest.raises(ValidationError, match="id_token"):
        auth.login_google(cuerpo)
    assert verificador.recibido == [] and usuarios.llamadas == []


def test_un_token_gigante_se_rechaza_antes_de_verificarlo():
    auth, verificador = _auth(UsuariosFalsos())
    with pytest.raises(ValidationError, match="largo"):
        auth.login_google({"id_token": "x" * 5000})
    assert verificador.recibido == []


def test_un_token_invalido_no_crea_ni_toca_cuentas():
    usuarios = UsuariosFalsos()
    auth, _ = _auth(usuarios, VerificadorFalso(error=UnauthorizedError("No se pudo validar su cuenta de Google.")))
    with pytest.raises(UnauthorizedError):
        auth.login_google({"id_token": "falso"})
    assert usuarios.llamadas == []


def test_sin_client_id_configurado_el_inicio_con_google_esta_desactivado():
    auth, _ = _auth(UsuariosFalsos(), verificador=None)
    with pytest.raises(ServiceUnavailableError, match="no está disponible"):
        auth.login_google({"id_token": "t"})


def test_si_el_correo_ya_esta_vinculado_a_otra_cuenta_de_google_es_409():
    class Usuarios(UsuariosFalsos):
        def vincular_google(self, usuario_id, sub):
            raise ConflictError("Esa cuenta ya está vinculada a otra cuenta de Google.")

    auth, _ = _auth(Usuarios(por_correo=un_usuario(id=7)))
    with pytest.raises(ConflictError, match="otra cuenta de Google"):
        auth.login_google({"id_token": "t"})
