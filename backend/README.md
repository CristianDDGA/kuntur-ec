# Backend · API REST (Flask + MVC)

## Patrón MVC

```
Petición HTTP
     │
     ▼
routes/      (C)  un Blueprint por servicio SOA: lee la petición, llama al servicio y responde
     │
     ▼
services/         reglas de negocio + acceso a Supabase con SQL parametrizado
     │
     ▼
models/      (M)  dataclasses que representan las tablas (from_row / to_dict)
     │
     ▼
utils/formatos.py (V)  representa la respuesta en JSON o XML según la cabecera Accept
```

| Archivo / carpeta | Responsabilidad | No debe |
|---|---|---|
| `app.py` | `create_app()`: ensambla todo; punto de entrada | Tener rutas ni lógica |
| `config.py` | Configuración desde `.env` (estricta fuera de desarrollo) | — |
| `database.py` | Pool de conexiones a Supabase; `transaccion()` (COMMIT/ROLLBACK) y `python database.py` para aplicar `database/*.sql` | Tener reglas de negocio |
| `models/` | Dataclasses por tabla: `Usuario`, `Vuelo`, `Reserva`, `Token`, `TarifaIva` (base común en `base.py`) | Tener SQL ni HTTP |
| `services/` | Reglas de negocio y consultas; lanzan excepciones de `utils/excepciones.py` | Conocer Flask (`request`, `jsonify`) |
| `routes/` | Rutas `/api/...` agrupadas por servicio | Escribir SQL |
| `utils/formatos.py` | Vista: `JsonFormato`, `XmlFormato`, `to_primitive` | — |
| `utils/respuestas.py` | `respond()` y negociación de contenido | — |
| `utils/excepciones.py` | Excepciones de negocio (`NotFoundError`, `ConflictError`, …) | — |
| `utils/manejador_errores.py` | Traduce excepciones a `{"error","mensaje"}` + código HTTP | — |
| `utils/documentacion.py` | Swagger en `/api/docs/` | — |
| `utils/seguridad.py` *(sección B3)* | bcrypt y JWT | — |
| `utils/autenticacion.py` *(sección B4)* | Decoradores `@token_requerido`, `@rol_requerido` | — |

## Buenas prácticas aplicadas

- **SRP:** cada módulo tiene una sola razón para cambiar; un archivo por recurso.
- **OCP:** los formatos JSON/XML se registran en `create_app`; agregar uno no modifica código existente.
- **DIP:** los servicios reciben sus dependencias (conexión, utilidades) por constructor, así se prueban con *fakes*.
- **Sin duplicación:** normalización de tipos única, manejo de errores centralizado, autenticación en un decorador en vez de repetirla en cada ruta.
- **Seguridad:** bcrypt (no SHA256), JWT con PyJWT, secretos solo en `.env`, sin `print` de datos sensibles y sin exponer detalles internos en los errores.

## Estructura

```
backend/
├─ app.py                    # create_app + arranque
├─ config.py
├─ requirements.txt  .env.example  pytest.ini
├─ models/
├─ services/
├─ routes/                   # health_routes.py, ...
├─ utils/                    # formatos, respuestas, excepciones, manejador_errores, documentacion
└─ tests/
   ├─ unit/                  # servicios con fakes, formatos, configuración
   └─ integration/           # endpoints con el cliente de pruebas de Flask
```

Los scripts de la base de datos están en [`../database/`](../database/).

## Convenciones

- Montos (`Decimal`) se envían como texto con 2 decimales (`"204.70"`) en JSON y XML.
- Errores: `{"error": "<codigo>", "mensaje": "<texto>"}` con códigos en español
  (`datos_invalidos`, `no_autenticado`, `sin_permiso`, `no_encontrado`, `conflicto`, `error_interno`…).
- El IVA se lee de la tabla `tarifas_iva` (historial con vigencias); cada reserva guarda el IVA aplicado.
- `APP_ENV` distinto de `development`/`testing` exige `DATABASE_URL` y `JWT_SECRET_KEY`.

## Comandos

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python app.py                 # http://localhost:5000/api/health  ·  Swagger: /api/docs/
pytest -q
```

## Base de datos (Supabase)

1. Copiar `.env.example` como `.env` y pegar en `DATABASE_URL` la cadena del **Session pooler** de Supabase.
2. Crear las tablas y cargar los datos iniciales (se puede repetir sin duplicar nada):

   ```bash
   python database.py
   ```

3. Comprobar: `GET /api/health` debe responder `"base_datos": "conectada"`.

Los scripts están en `database/schema.sql` (5 tablas con restricciones y RLS) y `database/seed.sql`
(historial de IVA, un administrador de desarrollo y vuelos de ejemplo).
Las pruebas de `tests/integration/test_database_real.py` usan la BD real y se omiten si no hay `DATABASE_URL`.
