from utils.seguridad import CifradorContrasenas

cifrador = CifradorContrasenas(costo=4)  # costo bajo: pruebas rápidas


def test_el_hash_no_contiene_la_contrasena_y_se_verifica():
    hash_ = cifrador.cifrar("Clave2026")
    assert "Clave2026" not in hash_
    assert hash_.startswith("$2b$")
    assert cifrador.verificar("Clave2026", hash_)
    assert not cifrador.verificar("Clave2027", hash_)


def test_la_misma_contrasena_genera_hashes_distintos_por_la_sal():
    assert cifrador.cifrar("Clave2026") != cifrador.cifrar("Clave2026")


def test_un_hash_con_formato_invalido_no_se_acepta():
    assert not cifrador.verificar("Clave2026", "no-es-un-hash")
