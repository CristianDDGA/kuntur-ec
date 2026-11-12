# Kuntur EC ✈️

> Sistema distribuido de reservas de vuelos basado en **Arquitectura Orientada a Servicios (SOA)**.
> *Kuntur* significa **cóndor** en kichwa: el ave que domina los cielos de los Andes ecuatorianos.

**Stack:** Flask (API REST · MVC · JWT · JSON/XML) · Flutter web · Supabase (PostgreSQL)

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

## Pruebas

```bash
cd backend  && python -m pytest        # API (incluye pruebas contra la base real configurada en .env)
cd frontend && flutter analyze && flutter test
```

Colección de Postman en [`docs/postman/`](docs/postman/). Casos de prueba y capturas en
[`docs/PRUEBAS.md`](docs/PRUEBAS.md); evaluación de usabilidad (heurísticas de Nielsen) en
[`docs/USABILIDAD.md`](docs/USABILIDAD.md).

## Funcionalidades

- Registro e inicio de sesión (JWT con vencimiento: al vencer, la app cierra la sesión y avisa).
- Búsqueda de vuelos, detalle y **mapa de asientos** (el cliente elige asientos concretos).
- Reservas: crear, modificar (control de concurrencia por versión), cancelar y comprobante/factura en **XML**.
- Administrador: crea vuelos y gestiona el IVA (historial con vigencias); no reserva.

Ver la planificación completa en [`docs/PLANIFICACION.md`](docs/PLANIFICACION.md).
