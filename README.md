# Kuntur EC ✈️

> Sistema distribuido de reservas de vuelos basado en **Arquitectura Orientada a Servicios (SOA)**.
> *Kuntur* significa **cóndor** en kichwa: el ave que domina los cielos de los Andes ecuatorianos.

**Stack:** Flask (API REST · MVC · JWT · JSON/XML) · Flutter web · Supabase (PostgreSQL) · correo por SMTP · inicio de sesión con Google

Aplicación distribuida basada en Arquitectura Orientada a Servicios (SOA) para la asignatura
**Aplicaciones Distribuidas** (UTA, ciclo julio–diciembre 2026).

| Componente | Tecnología | Carpeta |
|---|---|---|
| Proveedor de servicios (API REST) | Python · Flask · MVC | [`backend/`](backend/) |
| Consumidor (cliente) | Flutter (web y móvil) · MVC | [`frontend/`](frontend/) |
| Base de datos | Supabase (PostgreSQL en la nube) | [`database/`](database/) |
| Documentación | Planificación, diagramas, pruebas, informe | [`docs/`](docs/) |

## Arquitectura

Patrón **MVC** en ambos lados, con una capa de servicios que concentra la lógica:

```
Flutter                                        Flask
pages (V) → controllers (C) → services  ──HTTP/JSON·XML──▶  routes (C) → services → models (M)
                 ▲                │                              │                       │
                 └── models (M) ◀─┘                              └── utils/formatos (V) ◀┘
                                                                         Supabase ◀──── SQL
```

**Buenas prácticas:** una responsabilidad por archivo (SRP), dependencias inyectadas para poder
probar con *fakes* (DIP), formatos de respuesta extensibles sin tocar código (OCP), sin código
duplicado, errores uniformes en español, contraseñas con bcrypt, JWT y secretos solo en `.env`.

## Arranque rápido

```bash
# Backend
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python app.py            # http://localhost:5000/api/health  ·  Swagger: /api/docs/

# Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

La app web queda en `http://localhost:<puerto>`; el backend debe estar en `http://localhost:5000`
(`CORS_ORIGINS` del `.env` debe incluir el origen del frontend). La base se crea con
[`database/`](database/) (esquema y datos semilla: cuenta de administrador).

### Configuración (`backend/.env`)

| Variable | Para qué | ¿Obligatoria? |
|---|---|---|
| `DATABASE_URL` | Cadena del *Session pooler* de Supabase | Sí (fuera de desarrollo) |
| `JWT_SECRET_KEY` | Firma de las sesiones; **mínimo 32 caracteres** fuera de desarrollo | Sí (fuera de desarrollo) |
| `CORS_ORIGINS` | Orígenes del frontend separados por comas; `*` **solo** en desarrollo | Sí (fuera de desarrollo) |
| `SMTP_HOST` · `SMTP_PORT` · `SMTP_USER` · `SMTP_PASSWORD` · `SMTP_FROM` | Envío del código de verificación (Gmail con [contraseña de aplicación](https://myaccount.google.com/apppasswords), requiere verificación en dos pasos) | Sí (fuera de desarrollo). Sin ellas, en desarrollo el código se escribe en el log del servidor |
| `GOOGLE_CLIENT_ID` | ID de cliente OAuth web para «Continuar con Google» (no es secreto) | No: vacío = el botón responde que no está disponible |

Con `APP_ENV` distinto de `development`/`testing` el servidor **no arranca** si falta alguna obligatoria.
El frontend toma el mismo ID de cliente de Google de `--dart-define=GOOGLE_CLIENT_ID=...` y la URL de la API de
`--dart-define=API_BASE_URL=...` (ver [`frontend/README.md`](frontend/README.md)).

> Los secretos (`.env`, contraseña de aplicación) nunca se suben al repositorio: `.env` está en `.gitignore`.

## Pruebas

```bash
cd backend  && python -m pytest        # API (incluye pruebas contra la base real configurada en .env)
cd frontend && flutter analyze && flutter test
```

Colección de Postman en [`docs/postman/`](docs/postman/) (incluye aviones por CSV, cédula, verificación del correo y Google). Casos de prueba y capturas en
[`docs/PRUEBAS.md`](docs/PRUEBAS.md); evaluación de usabilidad (heurísticas de Nielsen) en
[`docs/USABILIDAD.md`](docs/USABILIDAD.md). Qué datos usa el sistema y cómo se protegen (también la usa Google para
el inicio de sesión): [`docs/PRIVACIDAD.md`](docs/PRIVACIDAD.md).

## Funcionalidades

- **Página de inicio** pública (`/`) que presenta el sistema y lleva a iniciar sesión o registrarse.
- **Registro** con nombre, **cédula ecuatoriana** (se valida provincia y dígito verificador, módulo 10; es única) y
  correo. La cuenta nace sin verificar: se envía un **código de 6 dígitos al correo** (vence a los 10 minutos, 5
  intentos, reenvío cada 60 s) y solo después de confirmarlo se puede entrar.
- **Inicio de sesión con Google:** el servidor valida el `id_token` con las claves públicas de Google. Si no hay
  cuenta la crea (con el correo ya verificado) y la app pide la cédula antes de continuar; si ya había una cuenta con
  ese correo, la vincula.
- Sesión con JWT con vencimiento: al vencer, la app cierra la sesión y avisa. Rutas protegidas por rol.
- Búsqueda de vuelos, detalle y **mapa de asientos** (el cliente elige asientos concretos).
- Reservas: crear, modificar (control de concurrencia por versión), cancelar y comprobante/factura en **XML**.
- Administrador: **importa la flota (aviones) desde un CSV** (`matricula;modelo;filas`, con revisión previa y errores
  por línea), crea vuelos eligiendo un avión (su capacidad define los asientos) y gestiona el IVA (historial con
  vigencias); no reserva.

Ver la planificación completa en [`docs/PLANIFICACION.md`](docs/PLANIFICACION.md).
