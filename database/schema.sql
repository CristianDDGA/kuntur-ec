-- =====================================================================
-- Kuntur EC · Esquema de la base de datos (Supabase / PostgreSQL)
--
-- Ejecutar en Supabase -> SQL Editor (o con psql). Es idempotente:
-- se puede volver a ejecutar sin errores ni pérdida de datos.
-- Los nombres de columnas coinciden con los modelos de backend/models/.
-- =====================================================================

-- ---------------------------------------------------------------------
-- usuarios
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL CHECK (btrim(nombre) <> ''),
    correo          VARCHAR(150) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    rol             VARCHAR(10)  NOT NULL DEFAULT 'cliente' CHECK (rol IN ('cliente', 'admin')),
    fecha_registro  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- El correo es único sin distinguir mayúsculas (Ana@x.com = ana@x.com).
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_correo ON usuarios (lower(correo));

-- ---------------------------------------------------------------------
-- vuelos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vuelos (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                VARCHAR(10)   NOT NULL UNIQUE,
    origen                VARCHAR(80)   NOT NULL CHECK (btrim(origen) <> ''),
    destino               VARCHAR(80)   NOT NULL CHECK (btrim(destino) <> ''),
    fecha                 DATE          NOT NULL,
    hora_salida           TIME          NOT NULL,
    hora_llegada          TIME          NOT NULL,
    precio                NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    capacidad             INTEGER       NOT NULL CHECK (capacidad BETWEEN 1 AND 200),
    asientos_disponibles  INTEGER       NOT NULL,
    version               INTEGER       NOT NULL DEFAULT 1 CHECK (version >= 1),
    CONSTRAINT ck_vuelos_ruta     CHECK (lower(btrim(origen)) <> lower(btrim(destino))),
    -- Nunca negativos ni más que la capacidad: protege contra sobreventa.
    CONSTRAINT ck_vuelos_asientos CHECK (asientos_disponibles BETWEEN 0 AND capacidad)
);

-- Búsqueda de vuelos: GET /api/vuelos?origen=&destino=&fecha=
CREATE INDEX IF NOT EXISTS ix_vuelos_busqueda ON vuelos (lower(origen), lower(destino), fecha);

-- ---------------------------------------------------------------------
-- tarifas_iva: historial del IVA (cambiarlo = insertar una tarifa nueva)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tarifas_iva (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    porcentaje     NUMERIC(5,2) NOT NULL CHECK (porcentaje BETWEEN 0 AND 100),
    vigente_desde  DATE         NOT NULL UNIQUE,
    vigente_hasta  DATE         NULL,  -- NULL = vigente hasta nuevo aviso
    CONSTRAINT ck_tarifas_iva_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta > vigente_desde)
);

-- Solo puede haber una tarifa abierta (sin fecha de fin) a la vez.
CREATE UNIQUE INDEX IF NOT EXISTS ux_tarifas_iva_abierta ON tarifas_iva ((vigente_hasta IS NULL))
    WHERE vigente_hasta IS NULL;

-- ---------------------------------------------------------------------
-- reservas: guarda la "foto" de los montos al reservar
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservas (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id         BIGINT        NOT NULL REFERENCES usuarios (id) ON DELETE RESTRICT,
    vuelo_id           BIGINT        NOT NULL REFERENCES vuelos (id)   ON DELETE RESTRICT,
    cantidad_asientos  INTEGER       NOT NULL CHECK (cantidad_asientos > 0),
    subtotal           NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),
    iva_porcentaje     NUMERIC(5,2)  NOT NULL CHECK (iva_porcentaje BETWEEN 0 AND 100),
    iva_valor          NUMERIC(10,2) NOT NULL CHECK (iva_valor >= 0),
    total              NUMERIC(10,2) NOT NULL,
    estado             VARCHAR(12)   NOT NULL DEFAULT 'confirmada'
                                     CHECK (estado IN ('confirmada', 'cancelada')),
    fecha_reserva      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    version            INTEGER       NOT NULL DEFAULT 1 CHECK (version >= 1),
    CONSTRAINT ck_reservas_total CHECK (total = subtotal + iva_valor)
);

CREATE INDEX IF NOT EXISTS ix_reservas_usuario ON reservas (usuario_id, fecha_reserva DESC);
CREATE INDEX IF NOT EXISTS ix_reservas_vuelo   ON reservas (vuelo_id);

-- ---------------------------------------------------------------------
-- reserva_asientos: qué asientos concretos tiene cada reserva ("1A", "12D"...).
-- El asiento es único por vuelo MIENTRAS la reserva esté activa (índice parcial): así dos
-- personas nunca pueden quedarse con el mismo asiento, aunque lo pidan en el mismo instante.
-- Al cancelar, los asientos quedan en el historial de la reserva (activo = false) y se liberan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reserva_asientos (
    reserva_id  BIGINT     NOT NULL REFERENCES reservas (id) ON DELETE CASCADE,
    vuelo_id    BIGINT     NOT NULL REFERENCES vuelos (id)   ON DELETE RESTRICT,
    asiento     VARCHAR(4) NOT NULL CHECK (asiento ~ '^[1-9][0-9]{0,2}[A-D]$'),
    activo      BOOLEAN    NOT NULL DEFAULT TRUE,
    PRIMARY KEY (reserva_id, asiento)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_asiento_activo_por_vuelo ON reserva_asientos (vuelo_id, asiento) WHERE activo;

-- ---------------------------------------------------------------------
-- tokens: sesiones emitidas, para revocarlas en el logout.
-- `token` guarda la huella SHA-256 del JWT (64 caracteres), nunca el JWT.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tokens (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id  BIGINT      NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
    token       TEXT        NOT NULL UNIQUE,
    expiracion  TIMESTAMPTZ NOT NULL,
    estado      VARCHAR(10) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'revocado'))
);

CREATE INDEX IF NOT EXISTS ix_tokens_usuario ON tokens (usuario_id);

-- ---------------------------------------------------------------------
-- Control de concurrencia optimista (columna version)
-- Cada UPDATE hace `version = version + 1`. Quien modifica envía la versión
-- que leyó; si otro la cambió antes, el UPDATE ... WHERE version = ? no
-- afecta filas y la API responde 409 "Ya actualizaron este registro".
-- (ADD COLUMN IF NOT EXISTS: agrega la columna en bases creadas antes.)
-- ---------------------------------------------------------------------
ALTER TABLE vuelos   ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1);
ALTER TABLE reservas ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1);

-- Capacidad máxima de 200 asientos por vuelo (mapa de asientos manejable). Se reaplica en bases
-- creadas antes con otro límite.
ALTER TABLE vuelos DROP CONSTRAINT IF EXISTS ck_vuelos_capacidad_maxima;
ALTER TABLE vuelos ADD CONSTRAINT ck_vuelos_capacidad_maxima CHECK (capacidad BETWEEN 1 AND 200);

-- ---------------------------------------------------------------------
-- Seguridad de Supabase
-- Supabase publica las tablas de `public` en su API REST automática.
-- Se activa RLS sin políticas: nadie con la clave pública (anon) puede
-- leerlas; solo nuestro backend, que se conecta como dueño de las tablas.
-- ---------------------------------------------------------------------
ALTER TABLE usuarios    ENABLE ROW LEVEL SECURITY;
ALTER TABLE vuelos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarifas_iva ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE reserva_asientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens      ENABLE ROW LEVEL SECURITY;
