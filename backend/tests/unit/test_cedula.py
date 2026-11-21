import pytest

from models import Rol, Usuario
from tests.factories import un_usuario
from utils.excepciones import ValidationError
from utils.validaciones import cedula, es_cedula

def test_se_comprueban_las_cedulas_de_ejemplo():
    # El verificador se calcula en la prueba (_completar), no se memoriza.
    for base in ("171003406", "010203040", "091234567", "175000000", "301003406"):
        assert es_cedula(_completar(base)), base


def _completar(nueve: str) -> str:
    """Agrega el dígito verificador a los 9 primeros dígitos (módulo 10)."""
    suma = 0
    for digito, coef in zip(map(int, nueve), (2, 1, 2, 1, 2, 1, 2, 1, 2)):
        producto = digito * coef
        suma += producto - 9 if producto > 9 else producto
    return nueve + str((10 - suma % 10) % 10)


def test_cambiar_un_solo_digito_la_invalida():
    # Es la garantía que se busca: con el verificador, un número "casi igual" a uno válido no pasa.
    valida = "1710034065"
    assert es_cedula(valida)
    for posicion in range(10):
        for reemplazo in "0123456789":
            if reemplazo == valida[posicion]:
                continue
            otra = valida[:posicion] + reemplazo + valida[posicion + 1:]
            if es_cedula(otra):  # solo puede pasar si el cambio compensa el verificador (nunca con 1 dígito)
                pytest.fail(f"{otra} no debería ser válida")


@pytest.mark.parametrize(
    "valor",
    [
        "",
        "171003406",       # 9 dígitos
        "17100340651",     # 11 dígitos
        "17100340a5",      # letra
        "1710034 65",      # espacio dentro
        "-710034065",      # signo
        "０１０２０３０４０５",  # dígitos de ancho completo (no son 0-9)
        "0010034065",      # provincia 00
        "2510034065",      # provincia 25
        "9910034065",      # provincia 99
        "1760034065",      # tercer dígito 6
        "1790034065",      # tercer dígito 9
    ],
)
def test_rechaza_lo_que_no_puede_ser_una_cedula(valor):
    assert es_cedula(valor) is False


def test_acepta_las_provincias_del_1_al_24_y_la_30():
    for provincia in [*range(1, 25), 30]:
        assert es_cedula(_completar(f"{provincia:02d}1003406")), provincia


def test_el_validador_de_campo_recorta_los_extremos_y_exige_el_dato():
    assert cedula({"cedula": " 1710034065 "}) == "1710034065"
    with pytest.raises(ValidationError, match="no puede superar|no es válida"):
        cedula({"cedula": "17100 34065"})  # un espacio dentro no se perdona
    for datos in ({}, {"cedula": None}, {"cedula": "   "}, {"cedula": 1710034065}):
        with pytest.raises(ValidationError, match="obligatorio"):
            cedula(datos)
    with pytest.raises(ValidationError, match="no es válida"):
        cedula({"cedula": "1710034066"})


def test_el_modelo_usuario_acepta_sin_cedula_pero_no_una_invalida():
    assert un_usuario(cedula=None).cedula is None  # cuentas anteriores (p. ej. el administrador)
    assert un_usuario(cedula="1710034065").to_dict()["cedula"] == "1710034065"
    with pytest.raises(ValidationError, match="cédula"):
        Usuario(id=1, nombre="Ana", correo="a@b.com", password_hash="h", rol=Rol.CLIENTE,
                fecha_registro=None, cedula="1710034066")
