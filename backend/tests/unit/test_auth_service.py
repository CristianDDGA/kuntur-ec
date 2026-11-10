import pytest

from services.auth_service import AuthService, Sesion
from tests.factories import un_usuario
from tests.fakes import BaseDatosFalsa
from utils.excepciones import UnauthorizedError, ValidationError
from utils.seguridad import CifradorContrasenas, EmisorTokens, huella_token

cifrador = CifradorContrasenas(costo=4)
emisor = EmisorTokens("clave-de-pruebas-suficientemente-larga-32b", 60)
USUARIO = un_usuario(password_hash=cifrador.cifrar("Clave2026"))


class UsuariosFalsos:
    def __init__(self, usuario=None):
        self.usuario = usuario

    def buscar_por_correo(self, correo):
        return self.usuario


def _servicio(db=None, usuario=USUARIO):
    return AuthService(db or BaseDatosFalsa(), UsuariosFalsos(usuario), emisor, cifrador)


def test_login_correcto_emite_token_y_guarda_solo_su_huella():
    db = BaseDatosFalsa()
    resultado = _servicio(db).login({"correo": "juan@correo.com", "password": "Clave2026"})

    assert resultado["tipo"] == "Bearer"
    assert "password_hash" not in resultado["usuario"]
    assert emisor.leer(resultado["token"]).usuario_id == USUARIO.id
    sql, params = db.cursor.consultas[0]
    assert "INSERT INTO tokens" in sql
    assert params[1] == huella_token(resultado["token"]) != resultado["token"]


@pytest.mark.parametrize("usuario", [USUARIO, None], ids=["clave-incorrecta", "correo-inexistente"])
def test_login_fallido_da_el_mismo_mensaje_sin_revelar_si_el_correo_existe(usuario):
    db = BaseDatosFalsa()
    with pytest.raises(UnauthorizedError, match="Correo o contraseña incorrectos"):
        _servicio(db, usuario).login({"correo": "juan@correo.com", "password": "Otra2026"})
    assert db.cursor.consultas == []


@pytest.mark.parametrize(
    "datos",
    [{}, {"correo": "a@b.com"}, {"correo": " ", "password": "x"}, {"correo": 1, "password": "x"}],
)
def test_login_sin_datos_es_400(datos):
    with pytest.raises(ValidationError):
        _servicio().login(datos)


def test_validar_token_activo_devuelve_la_sesion():
    token = emisor.emitir(USUARIO.id, "cliente").valor
    fila = USUARIO.to_dict() | {"password_hash": USUARIO.password_hash}
    sesion = _servicio(BaseDatosFalsa(filas=[fila])).validar(token)
    assert sesion.usuario.id == USUARIO.id and not sesion.es_admin


def test_validar_token_revocado_es_401():
    token = emisor.emitir(USUARIO.id, "cliente").valor
    with pytest.raises(UnauthorizedError, match="sesión fue cerrada"):
        _servicio(BaseDatosFalsa(filas=[None])).validar(token)


def test_logout_revoca_y_un_segundo_logout_es_401():
    db = BaseDatosFalsa()
    db.cursor.rowcount = 1
    _servicio(db).logout(Sesion(USUARIO, "tok"))
    assert "UPDATE tokens SET estado" in db.cursor.consultas[0][0]

    db.cursor.rowcount = 0
    with pytest.raises(UnauthorizedError):
        _servicio(db).logout(Sesion(USUARIO, "tok"))
