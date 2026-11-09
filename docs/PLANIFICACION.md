# APE 4 – Sistema de Reservas de Vuelos (SOA) · Planificación

## 1. Qué nos piden (fuentes: `APE4_AD.pdf` + `APE4.png`)

| Requisito | Fuente | Cómo lo cumplimos |
|---|---|---|
| Arquitectura SOA con servicios web REST o SOAP | Guía | REST con Flask, un servicio por dominio (Usuarios, Auth, Vuelos, Reservas) |
| Identificar servicios, contratos, consumidores y proveedores | Guía | Tabla de servicios + contrato OpenAPI (Swagger) |
| Diagrama de arquitectura | Guía + infografía | Diagrama SOA (cliente → API → Supabase) |
| Servicios mínimos: registro, autenticación, consulta de vuelos, reserva, gestión de reservas | Guía | Endpoints de la sección 4 |
| Cliente web, escritorio o móvil | Guía (infografía: Flutter) | Frontend Flutter (web) |
| HTTP/HTTPS, JSON **o** XML | Guía | JSON por defecto + XML (comprobante/factura y `Accept: application/xml`) |
| JWT para autenticación | Infografía | `flask-jwt-extended` + tabla `tokens` |
| BD en la nube | Infografía | Supabase (PostgreSQL) |
| Pruebas funcionales por servicio, validar respuestas y errores, con capturas | Guía | Postman/pytest + capturas |
| Entregable: un único PDF con el formato de la Guía APE | Guía | Informe siguiendo la estructura del ejemplo |

## 2. Lecciones del informe de ejemplo (guía 8)

**Lo que conviene mantener:** estructura del informe (Portada, Objetivos, Modalidad, Tiempo, Instrucciones, Recursos/TAC, Actividades, Resultados, Habilidades blandas, Conclusiones, Recomendaciones, Referencias, Anexos), Flutter + Flask + Supabase, JWT, roles (admin crea vuelos), control de concurrencia.

**Lo que debemos hacer mejor:**
1. **Coherencia:** el objetivo dice WCF pero implementaron Flask. Nosotros declaramos Flask/REST desde el inicio.
2. **Faltan diagrama de arquitectura y contratos de endpoints** (los pide la guía explícitamente). Los incluimos.
3. **No hay evidencia de pruebas de servicios** (solo pantallas). Agregamos pruebas por endpoint con casos de éxito y error (400/401/404/409).
4. **No usan XML.** Nosotros sí (comprobante XML de la reserva, como muestra la infografía).
5. **SHA256 para contraseñas** es débil (rápido, sin sal). Usamos **bcrypt** y lo justificamos en el informe.
6. Secciones vacías/residuos ("1. P", "2. Y") → revisar formato final.

## 3. Arquitectura propuesta

```
┌──────────────┐  HTTPS + JSON/XML  ┌───────────────────────────────┐   SQL    ┌──────────────┐
│ Cliente      │ ─────────────────▶ │ API REST Flask (proveedor)    │ ───────▶ │ Supabase     │
│ Flutter      │ ◀───────────────── │  ├─ Servicio Usuarios         │          │ PostgreSQL   │
│ (consumidor) │   Bearer JWT       │  ├─ Servicio Autenticación    │          │ (nube)       │
└──────────────┘                    │  ├─ Servicio Vuelos           │          └──────────────┘
                                    │  └─ Servicio Reservas         │
                                    │ Capas: rutas → servicios →    │
                                    │        repositorios           │
                                    │ Swagger UI en /api/docs       │
                                    └───────────────────────────────┘
```

- **Consumidor:** app Flutter. **Proveedor:** API Flask. **Contrato:** OpenAPI 3 (`/api/docs`).
- Cada servicio es un *Blueprint* independiente con su propia lógica y acceso a datos (bajo acoplamiento, alta cohesión).
- Opcional (punto extra): Docker Compose + Nginx como API Gateway.

## 4. Contratos (endpoints)

| Servicio | Método | Endpoint | Auth | Descripción |
|---|---|---|---|---|
| Usuarios | POST | `/api/usuarios/registro` | – | Crea usuario (nombre, correo, password) |
| Auth | POST | `/api/auth/login` | – | Devuelve JWT |
| Auth | POST | `/api/auth/logout` | JWT | Revoca token (tabla `tokens`) |
| Vuelos | GET | `/api/vuelos?origen=&destino=&fecha=` | – | Lista/filtra vuelos |
| Vuelos | GET | `/api/vuelos/{id}` | – | Detalle de vuelo |
| Vuelos | POST | `/api/vuelos` | JWT admin | Crea vuelo (extra) |
| Reservas | POST | `/api/reservas` | JWT | Crea reserva `{vuelo_id, cantidad}` |
| Reservas | GET | `/api/reservas` | JWT | Historial del usuario |
| Reservas | GET | `/api/reservas/{id}` | JWT | Detalle |
| Reservas | PUT | `/api/reservas/{id}` | JWT | Modifica cantidad |
| Reservas | DELETE | `/api/reservas/{id}` | JWT | Cancela (estado = `cancelada`, devuelve asientos) |
| Reservas | GET | `/api/reservas/{id}/comprobante` | JWT | Factura en **XML** (subtotal, IVA 15 %, total) |

Ejemplo (de la infografía): `POST /api/reservas {"usuario_id":1,"vuelo_id":10,"cantidad":2}` → `200 {"mensaje":"Reserva creada","reserva_id":58,"total":336.00,"estado":"confirmada"}`.
> Mejora: el `usuario_id` se toma del JWT, no del cuerpo (evita reservar a nombre de otro).

Formato de error uniforme: `{"error": "codigo", "mensaje": "texto"}` con 400 / 401 / 403 / 404 / 409 (sin asientos).

## 5. Modelo de datos (Supabase/PostgreSQL)

Basado en la infografía, con dos ajustes (marcados con ★):

- **usuarios**(id PK, nombre, correo UNIQUE, password_hash, ★rol `cliente|admin`, fecha_registro)
- **vuelos**(id PK, ★codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, ★capacidad, asientos_disponibles CHECK ≥ 0)
- **reservas**(id PK, usuario_id FK, vuelo_id FK, cantidad_asientos CHECK > 0, total, estado `confirmada|cancelada`, fecha_reserva)
- **tokens**(id PK, usuario_id FK, token, expiracion, estado `activo|revocado`)

Relaciones: usuarios 1–N reservas, vuelos 1–N reservas, usuarios 1–N tokens.

**Concurrencia:** descuento atómico en una transacción
`UPDATE vuelos SET asientos_disponibles = asientos_disponibles - :n WHERE id = :id AND asientos_disponibles >= :n` → si afecta 0 filas, responder 409.

## 6. Frontend Flutter (pantallas)

Login · Registro · Lista/búsqueda de vuelos · Detalle + reservar (cantidad) · Carrito/resumen (subtotal, IVA 15 %, total) · Mis reservas (ver, modificar, cancelar) · Comprobante XML · (Admin) crear vuelo.
Se ejecuta como **web** (`flutter run -d chrome`) y también puede compilarse a Android.
Paquetes: `flutter_riverpod` (estado + DI), `go_router`, `http`, `shared_preferences` (JWT), `xml`.

## 7. Estructura del repositorio (Clean Architecture + SOLID)

```
APE4-Distribuidas/
├─ backend/                 # Flask · ver backend/README.md
│  ├─ src/domain/           # entidades, interfaces de repositorio, excepciones
│  ├─ src/application/      # casos de uso, DTOs, ports
│  ├─ src/infrastructure/   # config, PostgreSQL (Supabase), bcrypt, JWT
│  ├─ src/presentation/api/ # blueprints por servicio, JSON/XML, errores, Swagger
│  ├─ src/container.py      # inyección de dependencias
│  ├─ sql/  tests/{unit,integration}/
├─ frontend/                # Flutter · ver frontend/README.md
│  └─ lib/{core, features/{auth,vuelos,reservas}/{data,domain,presentation}}
└─ docs/                    # planificación, referencias, diagramas, capturas, informe
```

**Política de dependencias:** versión exacta = antepenúltima estable de cada paquete.
Excepción documentada: `flasgger==0.9.7.1` (la 0.9.4 no funciona con Flask 3).

## 8. Plan de trabajo por secciones

| # | Sección | Estado |
|---|---|---|
| 0 | Repositorio + arquitectura back/front | ✅ Hecho |
| B1 | Dominio: entidades, interfaces de repositorio | ⏳ Siguiente |
| B2 | Base de datos Supabase: `schema.sql`, `seed.sql`, conexión | Pendiente |
| B3 | Servicio Usuarios (registro, bcrypt) | Pendiente |
| B4 | Servicio Auth (login/logout JWT, tabla tokens) | Pendiente |
| B5 | Servicio Vuelos (búsqueda, detalle, crear admin) | Pendiente |
| B6 | Servicio Reservas (crear, listar, modificar, cancelar, concurrencia) | Pendiente |
| B7 | Comprobante XML + Swagger completo + colección Postman | Pendiente |
| F1–F4 | Frontend: auth, vuelos, reservas, comprobante | Pendiente |
| P | Pruebas funcionales y capturas | Pendiente |
| D | Diagrama SOA + informe PDF | Pendiente |

## 9. Decisiones pendientes

- Nombre de la aplicación y datos de los integrantes del grupo.
- ¿Cuenta de Supabase ya creada? (se necesitan URL y cadena de conexión en `.env`, nunca en el código).
- ¿Desplegar la API en la nube (p. ej. Render) o solo local para la demo?
- ¿Incluir extras (selección de asientos como el ejemplo, Docker)?
