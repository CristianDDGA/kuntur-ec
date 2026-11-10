-- =====================================================================
-- Kuntur EC · Datos iniciales (ejecutar DESPUÉS de schema.sql)
--
-- Idempotente: si los datos ya existen no se duplican.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Historial del IVA en Ecuador
-- ---------------------------------------------------------------------
INSERT INTO tarifas_iva (porcentaje, vigente_desde, vigente_hasta) VALUES
    (12.00, DATE '2017-06-01', DATE '2024-04-01'),
    (15.00, DATE '2024-04-01', NULL)
ON CONFLICT (vigente_desde) DO NOTHING;

-- ---------------------------------------------------------------------
-- Usuario administrador de DESARROLLO (crea vuelos)
--   correo:     admin@kuntur.ec
--   contraseña: KunturAdmin2026   (hash bcrypt, costo 12)
-- Cambiar la contraseña antes de cualquier despliegue público.
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nombre, correo, password_hash, rol) VALUES
    ('Administrador Kuntur', 'admin@kuntur.ec',
     '$2b$12$YEbs2PVL3EcjOMhHYnOpLe9O6osaV14HI4cj/PwIfxav0yaSZFoJ2', 'admin')
ON CONFLICT ((lower(correo))) DO NOTHING;

-- ---------------------------------------------------------------------
-- Vuelos nacionales de ejemplo
-- ---------------------------------------------------------------------
INSERT INTO vuelos (codigo, origen, destino, fecha, hora_salida, hora_llegada,
                    precio, capacidad, asientos_disponibles) VALUES
    ('KT101', 'Quito',     'Guayaquil', DATE '2026-12-01', TIME '07:00', TIME '07:50',  89.00, 120, 120),
    ('KT102', 'Guayaquil', 'Quito',     DATE '2026-12-01', TIME '18:30', TIME '19:20',  89.00, 120, 120),
    ('KT201', 'Quito',     'Cuenca',    DATE '2026-12-03', TIME '08:15', TIME '09:05',  98.50,  90,  90),
    ('KT202', 'Cuenca',    'Quito',     DATE '2026-12-03', TIME '17:40', TIME '18:30',  98.50,  90,  90),
    ('KT301', 'Guayaquil', 'Galápagos', DATE '2026-12-10', TIME '09:30', TIME '11:20', 168.00, 150, 150),
    ('KT302', 'Galápagos', 'Guayaquil', DATE '2026-12-17', TIME '13:00', TIME '14:50', 168.00, 150, 150),
    ('KT401', 'Quito',     'Manta',     DATE '2026-12-12', TIME '06:45', TIME '07:30',  79.90,  70,  70),
    ('KT501', 'Quito',     'Loja',      DATE '2026-12-15', TIME '10:00', TIME '11:00', 105.00,  70,  70),
    ('KT601', 'Cuenca',    'Guayaquil', DATE '2026-12-20', TIME '12:10', TIME '12:55',  72.00,  90,  90),
    ('KT701', 'Quito',     'Coca',      DATE '2026-12-22', TIME '07:30', TIME '08:10',  85.00,  50,  50)
ON CONFLICT (codigo) DO NOTHING;
