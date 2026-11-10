import pytest
from psycopg.errors import UniqueViolation

from models import Rol
from services.usuario_service import UsuarioService
from tests.factories import un_usuario
from tests.fakes import BaseDatosFalsa, CifradorFalso
from utils.excepciones import ConflictError, ValidationError

DATOS = {"nombre": "  Ana   Torres ", "correo": " Ana@Correo.COM ", "password": "Clave2026"}


def _fila(**cambios):
    return un_usuario(**cambios).to_dict() | {"password_hash": "hash::Clave2026"}


def test_registrar_normaliza_datos_cifra_la_contrasena_y_asigna_rol_cliente():
    db = BaseDatosFalsa(filas=[_fila(nombre="Ana Torres", correo="ana@correo.com")])
    usuario = UsuarioService(db, CifradorFalso()).registrar(DATOS | {"rol": "admin"})

    sql, params = db.cursor.consultas[0]
    assert "INSERT INTO usuarios" in sql and "%s" in sql  # SQL parametrizado
    assert params == ("Ana Torres", "ana@correo.com", "hash::Clave2026", "cliente")
    assert usuario.rol is Rol.CLIENTE  # el "rol" enviado se ignora


@pytest.mark.parametrize(
    ("cambios", "mensaje"),
    [
        ({"nombre": None}, "'nombre' es obligatorio"),
        ({"correo": "   "}, "'correo' es obligatorio"),
        ({"password": 12345678}, "'password' es obligatorio"),
        ({"correo": "ana-sin-arroba"}, "correo no es válido"),
        ({"password": "Ab1"}, "al menos 8"),
        ({"password": "solamenteletras"}, "letras y números"),
        ({"password": "12345678"}, "letras y números"),
        ({"password": "A1" + "x" * 80}, "demasiado larga"),
        ({"nombre": "N" * 101}, "100 caracteres"),
    ],
)
def test_registrar_rechaza_datos_invalidos_sin_tocar_la_bd(cambios, mensaje):
    db = BaseDatosFalsa()
    with pytest.raises(ValidationError, match=mensaje):
        UsuarioService(db, CifradorFalso()).registrar(DATOS | cambios)
    assert db.cursor.consultas == []


def test_registrar_correo_repetido_es_conflicto():
    db = BaseDatosFalsa(error=UniqueViolation("duplicado"))
    with pytest.raises(ConflictError, match="Ya existe"):
        UsuarioService(db, CifradorFalso()).registrar(DATOS)


def test_buscar_por_correo():
    servicio = UsuarioService(BaseDatosFalsa(filas=[_fila()]), CifradorFalso())
    assert servicio.buscar_por_correo("JUAN@correo.com").correo == "juan@correo.com"
    assert UsuarioService(BaseDatosFalsa(), CifradorFalso()).buscar_por_correo("x@y.com") is None
