"""Límites de los campos de entrada: ÚNICA fuente en el código.

Cada valor es exactamente el tamaño de su columna en `database/schema.sql`:

    usuarios.nombre   VARCHAR(100)   -> NOMBRE_PERSONA
    usuarios.correo   VARCHAR(150)   -> CORREO
    vuelos.codigo     VARCHAR(10)    -> CODIGO_VUELO
    vuelos.origen     VARCHAR(80)    -> CIUDAD
    vuelos.destino    VARCHAR(80)    -> CIUDAD
    reserva_asientos.asiento VARCHAR(4) -> ASIENTO

Si se cambia el tamaño de una columna hay que cambiarlo aquí, y viceversa. La prueba
`tests/unit/test_limites_bd.py` compara estos valores con `schema.sql` y con la base real
y falla si se desincronizan, así un texto largo nunca llega a la base para dar un error 500.
"""

# --- texto (VARCHAR) ---
NOMBRE_PERSONA = 100
CORREO = 150
CODIGO_VUELO = 10
CIUDAD = 80
ASIENTO = 4  # "1A" ... "50D"

# --- reglas de negocio (siempre dentro de lo que admite la columna) ---
CONTRASENA = 128             # caracteres; bcrypt además solo admite 72 bytes
PRECIO_MAXIMO = 10_000       # NUMERIC(10,2) admitiría hasta 99 999 999,99
CAPACIDAD_MAXIMA = 200       # vuelos.capacidad (CHECK 1..200): el mapa de asientos debe ser manejable
ASIENTOS_POR_RESERVA = 10    # reservas.cantidad_asientos INTEGER

# --- numéricos de la base ---
MAX_ID = 10**18 - 1          # BIGINT admite hasta 9 223 372 036 854 775 807
MAX_VERSION = 2**31 - 1      # INTEGER
