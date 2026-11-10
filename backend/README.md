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
| `utils/documentacion.py` | Swagger en `/api/docs/`; `contrato(servicio, operacion)` ubica el `.yml` de cada endpoint | — |
| `docs/swagger/<servicio>/<operacion>.yml` | Contrato Swagger de cada endpoint (parámetros, respuestas, ejemplos) | — |
| `utils/seguridad.py` | `CifradorContrasenas` (bcrypt), `EmisorTokens` (JWT) y `huella_token` | — |
| `services/reserva_service.py` | Reservas en transacciones atómicas (UPDATE condicional de asientos, `FOR UPDATE`) | Conocer Flask |
| `services/vuelo_service.py` | Búsqueda con filtros, detalle y creación de vuelos | Conocer Flask |
| `utils/factura_xml.py` | Factura de la reserva como en clase: 1) JSON de la factura, 2) XML con `ElementTree` sección por sección | Recibir montos del cliente |
| `utils/peticiones.py` | `cuerpo_json()`: lee el JSON de la petición o responde 400 | — |
| `utils/autenticacion.py` | Decoradores `@token_requerido`, `@rol_requerido(Rol.ADMIN)` y `sesion_actual()` | Repetir la validación en cada ruta |

## Cómo se escribe un endpoint

Mismo estilo que en clase (`@route` con `methods`, separadores), con el contrato Swagger en un `.yml`:

```python
# =============================
# DELETE - Cancelar reserva
# =============================

@reservas_bp.route("/<int:reserva_id>", methods=["DELETE"])
@swag_from(contrato("reservas", "cancelar"))   # docs/swagger/reservas/cancelar.yml
@token_requerido                              # 401 si no hay sesión válida
def cancelar(reserva_id):
    detalle = _servicio().cancelar(sesion_actual(), reserva_id)
    return respond({"mensaje": "Reserva cancelada correctamente.", "reserva": detalle.to_dict()})
```

Los errores no se capturan en cada ruta: el servicio lanza `NotFoundError`, `ConflictError`…
y `utils/manejador_errores.py` responde `{"error", "mensaje"}` con el código HTTP, sin exponer detalles internos.

## Validaciones y manejo de errores

**Entrada (lista blanca, en `utils/validaciones.py`):** se define qué SÍ se acepta; lo demás se rechaza con 400.

| Campo | Se acepta | Se rechaza (ejemplos) |
|---|---|---|
| Nombre de persona / ciudad | Letras (con tildes, ñ), espacios, `'`, `.`, `-`; mín. 2 letras | Emojis 😀, números, `<script>`, comillas SQL, `#$%`, saltos de línea, caracteres invisibles |
| Correo | ASCII `a-z 0-9 . _ % + -` + dominio válido, en minúsculas | Emojis, espacios, `ana@-.com`, `..`, dos `@` |
| Contraseña | 8–128 caracteres con letras y números (emojis y símbolos permitidos) | Caracteres de control (NUL, `\n`, `\t`), más de 72 bytes |
| Código de vuelo | `A-Z 0-9 -`, 2 a 10 caracteres (se guarda en mayúsculas) | Emojis, símbolos |
| Precio | Mayor a 0, hasta 10 000, máximo 2 decimales | Negativos, 0, `NaN`, `Infinity`, `1e12`, 3 decimales |
| Enteros (cantidad, capacidad, versión) | Entero dentro de su rango | Texto, decimales, `true`, negativos, `10^30` |
| Ids (en la ruta y en el cuerpo) | Entero positivo de hasta 18 dígitos (`<id:...>`) | `-1`, `0`, `007`, `1e5`, ids gigantes → 404 |
| Fechas / horas | `AAAA-MM-DD` / `HH:MM` estrictos; vuelos hasta 2 años adelante | `01/12/2026`, `20261201`, `2026-02-30`, `25:00` |
| Cualquier texto del JSON | Sin caracteres de control (NUL, saltos…), JSON de máx. 4 niveles | NUL (`\x00`), JSON anidado 5000 niveles, `NaN` |

**Los límites de largo son los de la base de datos** (`utils/limites.py`): `nombre` 100, `correo` 150,
`codigo` 10, `origen`/`destino` 80, igual que sus `VARCHAR` en `schema.sql`. La prueba
`tests/unit/test_limites_bd.py` los compara con `schema.sql` y con la BD real, y falla si se desincronizan
o si alguien agrega una columna `VARCHAR` sin límite en el código.

**Errores de la API:** siempre `{"error": "<codigo>", "mensaje": "<texto en español>"}` en JSON o XML.

| HTTP | `error` | Cuándo |
|---|---|---|
| 400 | `datos_invalidos` | Datos que no cumplen las validaciones, JSON mal formado o no objeto |
| 401 | `no_autenticado` | Sin token, token inválido/expirado/revocado, credenciales incorrectas |
| 403 | `sin_permiso` | Cliente intentando una acción de administrador |
| 404 | `no_encontrado` | Ruta o recurso inexistente, id fuera de rango, reserva ajena |
| 405 | `metodo_no_permitido` | Método HTTP no soportado en esa ruta |
| 409 | `conflicto` | Correo o código repetido, sin asientos, versión vieja (`version_actual`), reserva cancelada |
| 413 | `cuerpo_demasiado_grande` | Cuerpo de más de 64 KB |
| 415 | `formato_no_soportado` | Cuerpo que no es `application/json` |
| 429 | `demasiados_intentos` | 5 logins fallidos por IP + correo en 15 min (cabecera `Retry-After`) |
| 500 | `error_interno` | Error inesperado: mensaje genérico, el detalle solo va al log del servidor |
| 503 | `servicio_no_disponible` | Base de datos sin respuesta (cabecera `Retry-After: 5`) |

**Nunca se filtran detalles internos** (SQL, trazas, nombres de tablas): `utils/manejador_errores.py` captura
todo; además traduce por sí solo los errores de PostgreSQL que ningún servicio previó
(dato fuera de rango → 400, violación de integridad → 409, conexión perdida → 503).

**Si la base de datos se cae** (`database.py`): la petición espera como máximo 5 s y responde 503 en lugar de
quedarse colgada; el pool reintenta en segundo plano y **la API se recupera sola en pocos segundos** cuando la
base vuelve, sin reiniciar. Cada consulta tiene un tiempo máximo de 10 s (`statement_timeout`).
`/api/health` sigue respondiendo y marca `"base_datos": "no_disponible"`.

Otras protecciones: cabeceras `X-Content-Type-Options: nosniff` y `Cache-Control: no-store` en la API; el login
responde igual si el correo existe o no y no ejecuta bcrypt cuando ya está bloqueado.
Alcance conocido: el límite de logins se cuenta en la memoria de cada servidor.

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
Las pruebas `tests/integration/test_*_real.py` usan la BD real y se omiten si no hay `DATABASE_URL`.

> El Session pooler del plan gratuito de Supabase admite **15 conexiones** a la vez. Cada proceso de la API usa
> un pool de hasta 5, así que no conviene levantar más de 2–3 instancias contra la misma base.
