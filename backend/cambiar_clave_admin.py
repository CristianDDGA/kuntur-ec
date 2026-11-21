"""Cambia la contraseña del administrador en la base configurada en DATABASE_URL.

Úselo ANTES de publicar: `database/seed.sql` trae una contraseña de desarrollo conocida.
    python cambiar_clave_admin.py
La contraseña se pide por teclado (no se muestra ni queda en el historial ni en el repositorio).
"""
import getpass
import sys

from dotenv import load_dotenv

from database import Database
from config import Settings
from utils.seguridad import CifradorContrasenas

MINIMO = 12


def main() -> int:
    load_dotenv()
    correo = input("Correo del administrador [admin@kuntur.ec]: ").strip() or "admin@kuntur.ec"
    nueva = getpass.getpass(f"Nueva contraseña (mínimo {MINIMO} caracteres): ")
    if len(nueva) < MINIMO or nueva.lower() == nueva or nueva.isalpha() or not any(c.isdigit() for c in nueva):
        print(f"Debe tener al menos {MINIMO} caracteres, con mayúsculas, minúsculas y números.")
        return 1
    if getpass.getpass("Repita la contraseña: ") != nueva:
        print("Las contraseñas no coinciden.")
        return 1

    db = Database.from_settings(Settings.from_env())
    try:
        with db.transaccion() as cur:
            cur.execute(
                "UPDATE usuarios SET password_hash = %s WHERE lower(correo) = lower(%s) AND rol = 'admin'",
                (CifradorContrasenas().cifrar(nueva), correo),
            )
            if cur.rowcount != 1:
                print("No existe un administrador con ese correo.")
                return 1
            # Cierra las sesiones abiertas con la contraseña anterior.
            cur.execute("DELETE FROM tokens WHERE usuario_id = (SELECT id FROM usuarios WHERE lower(correo) = lower(%s))", (correo,))
    finally:
        db.cerrar()
    print("Contraseña actualizada. Guárdela en un lugar seguro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
