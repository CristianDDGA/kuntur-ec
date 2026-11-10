# Kuntur EC · Planificación (APE 4 – Sistema de Reservas de Vuelos SOA)

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
| Usuarios | POST | `/api/usuarios/registro` | – | Crea usuario (nombre, correo, password) con rol `cliente` → 201 · 400 · 409 |
| Auth | POST | `/api/auth/login` | – | Devuelve JWT |
| Auth | POST | `/api/auth/logout` | JWT | Revoca token (tabla `tokens`) |
| Auth | GET | `/api/auth/perfil` | JWT | Datos del usuario autenticado (lo usa el frontend) |
| Vuelos | GET | `/api/vuelos?origen=&destino=&fecha=` | – | Lista/filtra vuelos desde hoy → `{total, vuelos}` · 400 fecha inválida |
| Vuelos | GET | `/api/vuelos/{id}` | – | Detalle de vuelo → 200 · 404 |
| Vuelos | POST | `/api/vuelos` | JWT admin | Crea vuelo → 201 · 400 · 401 · 403 · 409 código repetido |
| Reservas | POST | `/api/reservas` | JWT | Crea reserva `{vuelo_id, cantidad}` (1–10) → 201 · 400 · 404 · 409 sin asientos |
| Reservas | GET | `/api/reservas` | JWT | Historial del usuario |
| Reservas | GET | `/api/reservas/{id}` | JWT | Detalle |
| Reservas | PUT | `/api/reservas/{id}` | JWT | Modifica cantidad `{cantidad, version}` (mismo precio e IVA) → 200 · 409 "Ya actualizaron este registro" + `version_actual` |
| Reservas | DELETE | `/api/reservas/{id}` | JWT | Cancela (estado = `cancelada`, devuelve asientos) → 200 · 409 ya cancelada |
| Reservas | GET | `/api/reservas/{id}/comprobante` | JWT | Factura en **XML** (subtotal, IVA 15 %, total) |

Ejemplo (de la infografía): `POST /api/reservas {"usuario_id":1,"vuelo_id":10,"cantidad":2}` → `200 {"mensaje":"Reserva creada","reserva_id":58,"total":336.00,"estado":"confirmada"}`.
> Mejora: el `usuario_id` se toma del JWT, no del cuerpo (evita reservar a nombre de otro).

Reglas del registro: correo único sin distinguir mayúsculas, contraseña de 8+ caracteres con letras y números (cifrada con bcrypt, costo 12), el rol nunca se toma de la petición.

Reglas de la sesión: JWT HS256 firmado con `JWT_SECRET_KEY`, válido `JWT_EXPIRES_MINUTES` minutos; en la tabla `tokens` se guarda su huella SHA-256 (no el JWT); cada petición protegida verifica firma, expiración y que el token siga `activo`; el login fallido responde siempre "Correo o contraseña incorrectos" (no revela qué correos existen).

Reglas de vuelos: la búsqueda no distingue mayúsculas y solo muestra vuelos desde hoy; al crear, el código se guarda en mayúsculas y es único, la fecha no puede ser pasada, horas en `HH:MM`, precio con máximo 2 decimales, capacidad entera de 1 a 900 y `asientos_disponibles = capacidad`.

Formato de error uniforme: `{"error": "codigo", "mensaje": "texto"}` con 400 / 401 / 403 / 404 / 409 (sin asientos).

## 5. Modelo de datos (Supabase/PostgreSQL)

Basado en la infografía, con ajustes (marcados con ★):

- **usuarios**(id PK, nombre, correo UNIQUE, password_hash, ★rol `cliente|admin`, fecha_registro)
- **vuelos**(id PK, ★codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, ★capacidad, asientos_disponibles CHECK ≥ 0, ★version)
- **reservas**(id PK, usuario_id FK, vuelo_id FK, cantidad_asientos CHECK > 0, ★subtotal, ★iva_porcentaje, ★iva_valor, total, estado `confirmada|cancelada`, fecha_reserva, ★version)
- **tokens**(id PK, usuario_id FK, token, expiracion, estado `activo|revocado`)
- ★**tarifas_iva**(id PK, porcentaje, vigente_desde, vigente_hasta NULL)

Relaciones: usuarios 1–N reservas, vuelos 1–N reservas, usuarios 1–N tokens.

**IVA variable:** el porcentaje no está en el código ni en `.env`. Cambiarlo (p. ej. de 15 % a 12 %)
es insertar una tarifa nueva en `tarifas_iva` con su fecha de vigencia. Cada reserva guarda el
subtotal, el porcentaje y el valor del IVA aplicados, así las facturas antiguas no cambian.

**Concurrencia (implementado en B6, `services/reserva_service.py`).** Se aplican las tres técnicas vistas en clase (práctica `practica-sql-azure`), pero dentro de la BD, porque un `threading.Lock` solo protege a un proceso y la API puede correr en varios servidores:

| Técnica de clase | En Kuntur EC |
|---|---|
| UPDATE con condición | Descuento de asientos `WHERE asientos_disponibles >= n` (abajo) |
| Bloqueo (`threading.Lock`) | Bloqueo en la BD: `SELECT … FOR UPDATE` al modificar/cancelar |
| Versión (`WHERE id = ? AND version = ?` → 409) | Columna `version` en `vuelos` y `reservas`; `PUT /api/reservas/{id}` exige la versión leída |

Descuento atómico en una transacción
`UPDATE vuelos SET asientos_disponibles = asientos_disponibles - :n WHERE id = :id AND asientos_disponibles >= :n` → si afecta 0 filas, responder 409. Modificar y cancelar bloquean la reserva con `SELECT … FOR UPDATE`.
Verificado contra Supabase: 20 clientes reservando a la vez un vuelo de 5 asientos → 5 reservas (201) y 15 rechazos (409), 0 asientos libres; 5 cancelaciones simultáneas de la misma reserva → 1 cancelación y 4 rechazos (409), asientos devueltos una sola vez; 5 modificaciones simultáneas con la misma `version: 1` → 1 aceptada (version 2) y 4 × 409 "Ya actualizaron este registro" con `version_actual: 2`.
Una reserva ajena responde 404 (no se revela que existe).

## 6. Frontend Flutter (pantallas)

Login · Registro · Lista/búsqueda de vuelos · Detalle + reservar (cantidad) · Carrito/resumen (subtotal, IVA 15 %, total) · Mis reservas (ver, modificar, cancelar) · Comprobante XML · (Admin) crear vuelo.
Se ejecuta como **web** (`flutter run -d chrome`) y también puede compilarse a Android.
Paquetes: `flutter_riverpod` (estado + DI), `go_router`, `http`, `shared_preferences` (JWT), `xml`.

## 7. Estructura del repositorio (MVC + buenas prácticas)

Inspirada en la organización de otros grupos (APE8: `models`, `services`, `pages`, `widgets`…),
mejorada con controladores explícitos, inyección de dependencias, errores tipados y pruebas.

```
APE4-Distribuidas/
├─ backend/                 # Flask · ver backend/README.md
│  ├─ app.py  config.py     # create_app + configuración
│  ├─ models/               # M: dataclasses por tabla
│  ├─ services/             # reglas de negocio + SQL parametrizado
│  ├─ routes/               # C: un Blueprint por servicio SOA
│  ├─ utils/                # V: formatos JSON/XML · errores · Swagger · seguridad
│  └─ tests/{unit,integration}/
├─ frontend/                # Flutter · ver frontend/README.md
│  └─ lib/{config, models, services, controllers, pages, widgets}
├─ database/                # schema.sql, seed.sql (Supabase)
└─ docs/                    # planificación, referencias, diagramas, capturas, informe
```

**Política de dependencias:** versión exacta = antepenúltima estable de cada paquete.
Excepción documentada: `flasgger==0.9.7.1` (la 0.9.4 no funciona con Flask 3).

## 8. Plan de trabajo por secciones

| # | Sección | Estado |
|---|---|---|
| 0 | Repositorio + arquitectura back/front | ✅ Hecho |
| A | Cambio de arquitectura a MVC | ✅ Hecho |
| B1 | Modelos: Usuario, Vuelo, Reserva, Token, TarifaIva | ✅ Hecho |
| B2 | Base de datos Supabase: `schema.sql`, `seed.sql`, conexión | ✅ Hecho |
| B3 | Servicio Usuarios (registro, bcrypt) | ✅ Hecho |
| B4 | Servicio Auth (login/logout JWT, tabla tokens) | ✅ Hecho |
| B5 | Servicio Vuelos (búsqueda, detalle, crear admin) | ✅ Hecho |
| B6 | Servicio Reservas (crear, listar, modificar, cancelar, concurrencia) | ✅ Hecho |
| B7 | Comprobante XML + Swagger completo + colección Postman | ⏳ Siguiente |
| F1–F4 | Frontend: auth, vuelos, reservas, comprobante | Pendiente |
| P | Pruebas funcionales y capturas | Pendiente |
| D | Diagrama SOA + informe PDF | Pendiente |

## 9. Decisiones pendientes

- Nombre de la aplicación y datos de los integrantes del grupo.
- ¿Desplegar la API en la nube (p. ej. Render) o solo local para la demo?
- ¿Incluir extras (selección de asientos como el ejemplo, Docker)?
