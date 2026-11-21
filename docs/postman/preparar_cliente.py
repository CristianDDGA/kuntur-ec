"""Prepara el cliente que usa la colección de Postman: una cuenta YA VERIFICADA y con cédula.

La colección prueba reservas, así que necesita un cliente que pueda iniciar sesión. Una cuenta recién registrada no
puede (falta el código que llega por correo), por eso este script crea una verificada directamente en la base.

    cd backend
    .venv\\Scripts\\python ..\\docs\\postman\\preparar_cliente.py

Es idempotente: si el cliente ya existe, lo deja verificado y con la cédula esperada. Usa el DATABASE_URL de backend/.env.
Para quitarlo:  .venv\\Scripts\\python ..\\docs\\postman\\preparar_cliente.py --borrar
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2] / "backend"
sys.path.insert(0, str(BACKEND))
os.chdir(BACKEND)

from dotenv import load_dotenv  # noqa: E402

load_dotenv(BACKEND / ".env")

import psycopg  # noqa: E402

from utils.seguridad import CifradorContrasenas  # noqa: E402

CORREO = "cliente.postman@kuntur.test"
PASSWORD = "Clave2026"  # la misma que la variable cliente_password de la colección
CEDULA = "1700000001"  # válida (módulo 10) y distinta de las que usan las pruebas automáticas


def main() -> None:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("Falta DATABASE_URL en backend/.env")
    with psycopg.connect(url, autocommit=True) as conexion:
        if "--borrar" in sys.argv:
            conexion.execute("DELETE FROM tokens WHERE usuario_id IN (SELECT id FROM usuarios WHERE correo = %s)", (CORREO,))
            conexion.execute("DELETE FROM usuarios WHERE correo = %s", (CORREO,))
            print(f"Cliente {CORREO} borrado.")
            return
        conexion.execute(
            "INSERT INTO usuarios (nombre, correo, password_hash, rol, cedula, correo_verificado) "
            "VALUES ('Cliente Postman', %s, %s, 'cliente', %s, TRUE) "
            "ON CONFLICT ((lower(correo))) DO UPDATE SET correo_verificado = TRUE, cedula = EXCLUDED.cedula",
            (CORREO, CifradorContrasenas().cifrar(PASSWORD), CEDULA),
        )
    print(f"Cliente listo: {CORREO} / {PASSWORD} (verificado, cédula {CEDULA}).")


if __name__ == "__main__":
    main()
