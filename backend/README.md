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
| `config.py` | Configuración desde `.env`; fuera de desarrollo exige `DATABASE_URL`, `JWT_SECRET_KEY` (≥ 32 caracteres), `CORS_ORIGINS` sin `*` y `SMTP_*` | — |
| `database.py` | Pool de conexiones a Supabase; `transaccion()` (COMMIT/ROLLBACK) y `python database.py` para aplicar `database/*.sql` | Tener reglas de negocio |
| `models/` | Dataclasses por tabla: `Usuario`, `Vuelo`, `Avion`, `Reserva`, `Token`, `TarifaIva` (base común en `base.py`) | Tener SQL ni HTTP |
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
| `utils/autenticacion.py` | Decoradores `@publica`, `@token_requerido`, `@rol_requerido(...)` y `sesion_actual()`; `exigir_acceso_declarado` cierra por defecto toda ruta que no declare su acceso | Repetir la validación en cada ruta |
| `services/avion_service.py` · `utils/importacion_csv.py` | Flota: listar, **revisar** (sin guardar) e **importar** un CSV de aviones en una sola transacción | Conocer Flask |
| `services/verificacion_service.py` · `utils/correo.py` | Código de 6 dígitos para confirmar el correo (HMAC, vencimiento, intentos, reenvío) y envío por SMTP (`EnviadorSmtp`) o al log (`EnviadorLocal`) | Guardar el código en claro |
| `utils/google.py` | Valida el `id_token` de Google (firma, vencimiento, audiencia = nuestro ID de cliente, correo verificado) con `google-auth` | Confiar en el nombre o correo que diga el cliente |

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
| Cédula | 10 dígitos, provincia 01–24 o 30, tercer dígito < 6 y **dígito verificador correcto** (módulo 10) | Letras, 9 u 11 dígitos, espacios dentro, provincia 25+, verificador mal |
| Código de verificación | Exactamente 6 dígitos | Letras, 5 o 7 dígitos, dígitos de ancho completo |
| Matrícula / modelo / filas (aviones) | Matrícula `A-Z 0-9 -` de 3 a 10; modelo hasta 60; filas enteras de 1 a 50 | Matrículas repetidas en el archivo, filas 0 o 51, columnas de más o de menos |
| Código de vuelo | `A-Z 0-9 -`, 2 a 10 caracteres (se guarda en mayúsculas) | Emojis, símbolos |
| Precio | Mayor a 0, hasta 10 000, máximo 2 decimales | Negativos, 0, `NaN`, `Infinity`, `1e12`, 3 decimales |
| Enteros (cantidad, capacidad, versión) | Entero dentro de su rango | Texto, decimales, `true`, negativos, `10^30` |
| Ids (en la ruta y en el cuerpo) | Entero positivo de hasta 18 dígitos (`<id:...>`) | `-1`, `0`, `007`, `1e5`, ids gigantes → 404 |
| Fechas / horas | `AAAA-MM-DD` / `HH:MM` estrictos; vuelos hasta 2 años adelante | `01/12/2026`, `20261201`, `2026-02-30`, `25:00` |
| Cualquier texto del JSON | Sin caracteres de control (NUL, saltos…), JSON de máx. 4 niveles | NUL (`\x00`), JSON anidado 5000 niveles, `NaN` |

**Los límites de largo son los de la base de datos** (`utils/limites.py`): `nombre` 100, `correo` 150,
`cedula` 10, `codigo` 10, `matricula` 10, `modelo` 60, `origen`/`destino` 80, igual que sus `VARCHAR` en `schema.sql`. La prueba
`tests/unit/test_limites_bd.py` los compara con `schema.sql` y con la BD real, y falla si se desincronizan
o si alguien agrega una columna `VARCHAR` sin límite en el código.

**Errores de la API:** siempre `{"error": "<codigo>", "mensaje": "<texto en español>"}` en JSON o XML.

| HTTP | `error` | Cuándo |
|---|---|---|
| 400 | `datos_invalidos` | Datos que no cumplen las validaciones, JSON mal formado o no objeto |
| 401 | `no_autenticado` | Sin token, token inválido/expirado/revocado, credenciales incorrectas |
| 403 | `sin_permiso` | Cliente intentando una acción de administrador (o al revés) |
| 403 | `correo_no_verificado` | Credenciales correctas pero falta confirmar el correo (trae el campo `correo`) |
| 404 | `no_encontrado` | Ruta o recurso inexistente, id fuera de rango, reserva ajena |
| 405 | `metodo_no_permitido` | Método HTTP no soportado en esa ruta |
| 409 | `conflicto` | Correo, cédula o código repetido, sin asientos, versión vieja (`version_actual`), reserva cancelada, cédula que ya no se puede cambiar |
| 413 | `cuerpo_demasiado_grande` | Cuerpo de más de 64 KB (1 MB en la importación de aviones) |
| 415 | `formato_no_soportado` | Cuerpo que no es `application/json` (en la importación de aviones, que no es `text/csv`) |
| 429 | `demasiados_intentos` | 5 logins fallidos por IP + correo en 15 min (cabecera `Retry-After`) |
| 500 | `error_interno` | Error inesperado: mensaje genérico, el detalle solo va al log del servidor |
| 503 | `servicio_no_disponible` | Base de datos sin respuesta (cabecera `Retry-After: 5`), no se pudo enviar el correo o contactar a Google, o Google no está configurado |

**Nunca se filtran detalles internos** (SQL, trazas, nombres de tablas): `utils/manejador_errores.py` captura
todo; además traduce por sí solo los errores de PostgreSQL que ningún servicio previó
(dato fuera de rango → 400, violación de integridad → 409, conexión perdida → 503).

**Si la base de datos se cae** (`database.py`): la petición espera como máximo 5 s y responde 503 en lugar de
quedarse colgada; el pool reintenta en segundo plano y **la API se recupera sola en pocos segundos** cuando la
base vuelve, sin reiniciar. Cada consulta tiene un tiempo máximo de 10 s (`statement_timeout`).
`/api/health` sigue respondiendo y marca `"base_datos": "no_disponible"`.

**Cerrado por defecto:** una ruta nueva sin `@publica`, `@token_requerido` o `@rol_requerido` responde 500 en vez de
quedar abierta por olvido (`before_request`; lo verifica `tests/integration/test_cerrado_por_defecto.py`). Solo son
públicas: `/health`, registro, login (y Google, verificar/reenviar código, recuperar/restablecer contraseña) y la consulta de vuelos.

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
├─ routes/                   # un Blueprint por servicio: auth, usuarios, vuelos, aviones, reservas, iva, health
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
- `APP_ENV` distinto de `development`/`testing` exige `DATABASE_URL`, `JWT_SECRET_KEY` (≥ 32 caracteres), `CORS_ORIGINS` sin `*` y `SMTP_HOST`/`SMTP_USER`/`SMTP_PASSWORD`.

## Comandos

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python app.py                 # http://localhost:5000/api/health  ·  Swagger: /api/docs/
pytest -q
```

## Cuentas: cédula, correo y Google

```
Registro ──▶ cuenta SIN verificar ──▶ código de 6 dígitos por correo ──▶ POST /auth/verificar-correo ──▶ login
Google   ──▶ POST /auth/google ──▶ cuenta verificada, SIN cédula ──▶ PUT /usuarios/cedula ──▶ la app continúa
```

- **Cédula** (`utils/validaciones.py::es_cedula`): solo detecta números que no pueden ser una cédula; **no consulta
  ningún registro civil**, así que no prueba que la persona exista. Es única (índice parcial `ux_usuarios_cedula`) y
  una vez guardada no se cambia.
- **Verificación del correo** (`services/verificacion_service.py`): el código se guarda como HMAC-SHA256 (nunca en
  claro) en `codigos_verificacion`, uno vigente por cuenta. Vence a los 10 minutos; con 5 intentos fallidos hay que
  pedir otro; se puede pedir otro cada 60 s. `POST /auth/reenviar-codigo` responde igual exista o no la cuenta, para no
  revelar qué correos están registrados. Un login con contraseña correcta pero sin verificar responde
  `403 correo_no_verificado`; con contraseña incorrecta sigue siendo `401` (no se revela nada).
  Las cuentas anteriores a esta función quedaron verificadas.
- **Recuperación de contraseña** (`services/recuperacion_service.py`): mismo mecanismo que la verificación, con tabla propia
  (`codigos_recuperacion`) para que pedir uno no invalide el código del registro. `POST /auth/recuperar-clave` envía el código
  y responde siempre igual (exista o no la cuenta, salga o no el correo: no se revela qué correos están registrados).
  `POST /auth/restablecer-clave` (`correo`, `codigo`, `password`) valida el código, guarda la contraseña nueva (mismas reglas del
  registro; una contraseña floja no gasta un intento), **revoca todas las sesiones** de la cuenta y la deja verificada, porque el
  código prueba que la persona controla el correo. Una cuenta creada con Google también puede definir así una contraseña.
- **Google** (`services/auth_service.py::login_google`): el cliente solo envía el `id_token`; el servidor decide quién es
  la persona únicamente con lo que Google firmó. Si hay una cuenta vinculada (`google_sub`), entra; si hay una con ese
  correo, la vincula y la deja verificada; si no, crea un cliente nuevo con el correo ya verificado, sin cédula y con
  una contraseña aleatoria que nadie conoce. Sin `GOOGLE_CLIENT_ID` el endpoint responde 503.
- **Correo:** `EnviadorSmtp` (Gmail con contraseña de aplicación, TLS) o `EnviadorLocal` (solo desarrollo y pruebas: deja
  el mensaje en el log). **Las pruebas automáticas nunca envían correos reales.**

## Flota de aviones (importación por CSV)

Formato (UTF-8, coma o punto y coma, hasta 1 MB y 500 aviones):

```csv
matricula;modelo;filas
HC-ABC;Airbus A320;30
HC-XYZ;ATR 72;18
```

Cada fila del avión tiene 4 asientos (A–D), así que `capacidad = filas × 4` y los asientos `1A…50D` se generan a partir de
ahí. El vuelo guarda su `avion_id` y toma la capacidad del avión (la numeración de los asientos no cambió).

| Paso | Endpoint | Qué hace |
|---|---|---|
| 1. Revisar | `POST /api/aviones/importacion/validar` (`Content-Type: text/csv`) | No guarda nada: devuelve vista previa, matrículas ya registradas y **los errores por línea** |
| 2. Importar | `POST /api/aviones/importacion` | **Todo o nada**: si alguna fila tiene errores no se guarda ninguna (400 con la lista); las matrículas existentes se omiten |
| Listar | `GET /api/aviones` | Para elegir el avión al crear un vuelo (solo administrador) |

`POST /api/vuelos` acepta `avion_id` (su capacidad manda) o, por compatibilidad, `capacidad` si no se envía avión.

## Base de datos (Supabase)

1. Copiar `.env.example` como `.env` y pegar en `DATABASE_URL` la cadena del **Session pooler** de Supabase.
2. Crear las tablas y cargar los datos iniciales (se puede repetir sin duplicar nada):

   ```bash
   python database.py
   ```

3. Comprobar: `GET /api/health` debe responder `"base_datos": "conectada"`.

Los scripts están en `database/schema.sql` (8 tablas con restricciones y RLS) y `database/seed.sql`
(historial de IVA, un administrador de desarrollo y vuelos de ejemplo). `schema.sql` es idempotente: se puede
volver a ejecutar sobre una base existente y agrega las columnas nuevas (`ADD COLUMN IF NOT EXISTS`).
Las pruebas `tests/integration/test_*_real.py` usan la BD real y se omiten si no hay `DATABASE_URL`.

> El Session pooler del plan gratuito de Supabase admite **15 conexiones** a la vez. Cada proceso de la API usa
> un pool de hasta 5, así que no conviene levantar más de 2–3 instancias contra la misma base.
