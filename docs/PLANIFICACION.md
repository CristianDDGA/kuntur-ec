# Kuntur EC · Planificación (APE 4 – Sistema de Reservas de Vuelos SOA)

## 1. Qué nos piden (fuentes: `APE4_AD.pdf` + `APE4.png`)

| Requisito | Fuente | Cómo lo cumplimos |
|---|---|---|
| Arquitectura SOA con servicios web REST o SOAP | Guía | REST con Flask, un servicio por dominio (Usuarios, Auth, Vuelos, Reservas) |
| Identificar servicios, contratos, consumidores y proveedores | Guía | Tabla de servicios + contrato OpenAPI (Swagger) |
| Diagrama de arquitectura | Guía + infografía | Diagrama SOA (cliente → API → Supabase) |
| Servicios mínimos: registro, autenticación, consulta de vuelos, reserva, gestión de reservas | Guía | Endpoints de la sección 4 |
| Extras pedidos por el docente: aviones y asientos por CSV, cédula, página de inicio, correo real, inicio con Google | Docente | Secciones 4, 5 y 8 (fases Z0–Z5) |
| Cliente web, escritorio o móvil | Guía (infografía: Flutter) | Frontend Flutter (web) |
| HTTP/HTTPS, JSON **o** XML | Guía | JSON por defecto + XML (comprobante/factura y `Accept: application/xml`) |
| JWT para autenticación | Infografía | PyJWT (HS256) + tabla `tokens` con la huella SHA-256 |
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
| Usuarios | POST | `/api/usuarios/registro` | – | Crea usuario `{nombre, cedula, correo, password}` con rol `cliente`, **sin verificar**, y envía el código al correo → 201 `{usuario, verificacion_pendiente, codigo_enviado}` · 400 (cédula inválida incluida) · 409 (correo o cédula repetidos) |
| Usuarios | PUT | `/api/usuarios/cedula` | JWT cliente | Guarda la cédula de una cuenta que no la tiene (p. ej. creada con Google); no se cambia después → 200 · 400 · 403 · 409 |
| Auth | POST | `/api/auth/login` | – | Devuelve JWT → 200 · 401 · 403 `correo_no_verificado` (contraseña correcta, falta confirmar el correo) · 429 |
| Auth | POST | `/api/auth/verificar-correo` | – | Confirma el correo `{correo, codigo}` (6 dígitos, vence a los 10 min, 5 intentos) → 200 · 400 |
| Auth | POST | `/api/auth/reenviar-codigo` | – | Envía otro código `{correo}` (uno cada 60 s); responde igual exista o no la cuenta → 200 · 503 |
| Auth | POST | `/api/auth/google` | – | Inicia sesión con `{id_token}` de Google: valida el token, vincula o crea la cuenta (verificada, sin cédula) y devuelve el JWT + `nuevo` → 200 · 400 · 401 · 409 · 503 |
| Auth | POST | `/api/auth/logout` | JWT | Revoca token (tabla `tokens`) |
| Auth | GET | `/api/auth/perfil` | JWT | Datos del usuario autenticado (lo usa el frontend) |
| Vuelos | GET | `/api/vuelos?origen=&destino=&fecha=&pagina=&por_pagina=` | – | Lista/filtra vuelos que aún no parten (hoy solo los de salida posterior a la hora actual), paginada (10 por defecto, máx. 50) → `{total, pagina, por_pagina, total_paginas, vuelos}` · 400 fecha o paginación inválida |
| IVA | GET | `/api/iva` | JWT | Tarifa vigente e historial (`vigente`, `programada`, `anterior`) |
| IVA | POST | `/api/iva` | JWT admin | Programa una tarifa `{porcentaje 0–100, vigente_desde ≥ hoy}`; cierra la abierta el día anterior; no altera reservas hechas → 201 · 400 · 403 · 409 (ya hay una tarifa igual o posterior) |
| Vuelos | GET | `/api/vuelos/{id}` | – | Detalle de vuelo → 200 · 404 |
| Vuelos | GET | `/api/vuelos/{id}/asientos` | – | Mapa de asientos: `{vuelo_id, capacidad, columnas: [A,B,C,D], ocupados: ["2B"]}`. Los asientos existentes se deducen de la capacidad (1A, 1B, 1C, 1D, 2A…) → 200 · 404 |
| Vuelos | POST | `/api/vuelos` | JWT admin | Crea vuelo con `avion_id` (su capacidad = filas × 4 manda) o, por compatibilidad, `capacidad` → 201 · 400 · 401 · 403 · 404 avión inexistente · 409 código repetido |
| Aviones | GET | `/api/aviones` | JWT admin | Flota registrada (`matricula`, `modelo`, `filas`, `capacidad`) |
| Aviones | POST | `/api/aviones/importacion/validar` | JWT admin | Revisa un CSV (`Content-Type: text/csv`, `matricula;modelo;filas`) **sin guardar**: vista previa, existentes y errores por línea → 200 · 400 · 413 · 415 |
| Aviones | POST | `/api/aviones/importacion` | JWT admin | Importa el CSV, todo o nada (400 con la lista de errores si alguna fila falla; las matrículas existentes se omiten) → 201 |
| Reservas | POST | `/api/reservas` | JWT cliente | Crea reserva `{vuelo_id, asientos: ["1A","2B"]}` (1–10 asientos concretos; o solo `cantidad` → el sistema asigna los primeros libres) → 201 · 400 (incluye vuelo que ya partió: se compara fecha **y hora** de salida, o un asiento que no existe en ese vuelo) · 403 admin · 404 · 409 sin asientos o asiento ya tomado (trae `asientos_ocupados`) |
| Reservas | GET | `/api/reservas?pagina=&por_pagina=` | JWT cliente | Historial del usuario, paginado → `{total, pagina, por_pagina, total_paginas, reservas}` |
| Reservas | GET | `/api/reservas/{id}` | JWT cliente | Detalle |
| Reservas | PUT | `/api/reservas/{id}` | JWT cliente | Modifica los asientos `{asientos, version}` (cambiar de lugar, ampliar o reducir; mismo precio e IVA; también acepta `{cantidad, version}`) → 200 · 409 "Ya actualizaron este registro" + `version_actual` |
| Reservas | DELETE | `/api/reservas/{id}` | JWT cliente | Cancela (estado = `cancelada`, devuelve asientos) → 200 · 409 ya cancelada |
| Reservas | GET | `/api/reservas/{id}/comprobante` | JWT cliente | Factura en **XML** siempre, armada como en la práctica de clase (`practica-xml`): JSON de la factura → XML con `ElementTree` (`factura/cabecera/cliente/Detalle/producto/Totales/Estado`). Los montos salen de la reserva, no del cliente → 200 · 401 · 404 |

Ejemplo (de la infografía): `POST /api/reservas {"usuario_id":1,"vuelo_id":10,"cantidad":2}` → `200 {"mensaje":"Reserva creada","reserva_id":58,"total":336.00,"estado":"confirmada"}`.
> Mejora: el `usuario_id` se toma del JWT, no del cuerpo (evita reservar a nombre de otro).

Reglas del registro: correo único sin distinguir mayúsculas, **cédula ecuatoriana única** (10 dígitos, provincia, dígito verificador módulo 10; no se consulta ningún registro civil), contraseña de 8+ caracteres con letras y números (cifrada con bcrypt, costo 12), el rol nunca se toma de la petición. La cuenta nace **sin verificar**: no inicia sesión hasta confirmar el código que llega por correo (SMTP; las cuentas anteriores quedaron verificadas).

Reglas del inicio con Google: el servidor solo cree lo que firma Google (firma, vencimiento, audiencia = nuestro ID de cliente y `email_verified`); nunca el nombre o correo que envíe el cliente. Una cuenta de Google queda vinculada por su `sub` y sin contraseña usable. Todo cliente sin cédula debe completarla antes de seguir (la app lo fuerza).

Reglas de la sesión: JWT HS256 firmado con `JWT_SECRET_KEY`, válido `JWT_EXPIRES_MINUTES` minutos; en la tabla `tokens` se guarda su huella SHA-256 (no el JWT); cada petición protegida verifica firma, expiración y que el token siga `activo`; el login fallido responde siempre "Correo o contraseña incorrectos" (no revela qué correos existen).

Reglas de vuelos: la búsqueda no distingue mayúsculas y solo muestra vuelos desde hoy; al crear, el código lo genera el sistema (`KT101`, `KT102`…; si se envía uno se respeta, en mayúsculas y único), la fecha no puede ser pasada, horas en `HH:MM`, precio con máximo 2 decimales, capacidad entera de 1 a **200** (CHECK en la BD; el mapa de asientos debe ser manejable) y `asientos_disponibles = capacidad`.

Formato de error uniforme: `{"error": "codigo", "mensaje": "texto"}` con 400 / 401 / 403 / 404 / 409 (sin asientos) y, para casos de operación, 413 (cuerpo > 64 KB), 415 (no es JSON), 429 (límite de logins, con `Retry-After`), 500 (genérico, sin detalles internos) y 503 (base de datos caída). Tabla completa y reglas de validación en `backend/README.md`.

**Validación y robustez (B8):** lista blanca de caracteres (sin emojis, símbolos ni caracteres de control en nombres, ciudades, correos y códigos), rangos numéricos, ids seguros y límites de largo idénticos a los `VARCHAR` de la base (verificado por una prueba contra `schema.sql` y contra Supabase). Auditoría con 95 casos hostiles: de 29 fallos a 0. Con la base caída la API responde 503 en 5 s y se recupera sola en 2–5 s al volver.

## 5. Modelo de datos (Supabase/PostgreSQL)

Basado en la infografía, con ajustes (marcados con ★):

- **usuarios**(id PK, nombre, correo UNIQUE, password_hash, ★rol `cliente|admin`, fecha_registro, ★cedula UNIQUE parcial `^[0-9]{10}$` (NULL en cuentas antiguas), ★correo_verificado, ★google_sub UNIQUE parcial)
- ★**aviones**(id PK, matricula UNIQUE, modelo, filas 1–50, fecha_alta): capacidad = filas × 4; se cargan por CSV
- ★**codigos_verificacion**(usuario_id PK/FK, codigo_hash HMAC, expira, intentos, enviado_en): un código vigente por cuenta
- **reserva_asientos**(reserva_id FK, vuelo_id FK, asiento VARCHAR(4) `^[1-9][0-9]{0,2}[A-D]$`, activo, ★quitado; PK (reserva_id, asiento); **índice único parcial (vuelo_id, asiento) WHERE activo**: un asiento activo nunca se repite en un vuelo). Al cancelar, `activo = false` (queda en el historial y se libera); al quitar un asiento al modificar la reserva, `activo = false` y `quitado = true` (no se borra)
- **vuelos**(id PK, ★codigo, origen, destino, fecha, hora_salida, hora_llegada, precio, ★capacidad, asientos_disponibles CHECK ≥ 0, ★version, ★avion_id FK NULL en vuelos anteriores)
- **reservas**(id PK, usuario_id FK, vuelo_id FK, cantidad_asientos CHECK > 0, ★subtotal, ★iva_porcentaje, ★iva_valor, total, estado `confirmada|cancelada`, fecha_reserva, ★version)
- **tokens**(id PK, usuario_id FK, token, expiracion, estado `activo|revocado`)
- ★**tarifas_iva**(id PK, porcentaje, vigente_desde, vigente_hasta NULL)

Relaciones: usuarios 1–N reservas, vuelos 1–N reservas, usuarios 1–N tokens, aviones 1–N vuelos, usuarios 1–1 codigos_verificacion.

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

**Pruebas funcionales:** `docs/postman/KunturEC.postman_collection.json` (una carpeta por servicio, con casos de éxito y error 400/401/403/404/409/415 y pruebas `pm.test`). Ver `docs/postman/README.md`: necesita un cliente ya verificado (se prepara con un script).

## 6. Frontend Flutter (pantallas)

**Diseño:** estructura de APE8 (tarjeta centrada sobre fondo suave) con paleta de Ecuador sobria: azul de la bandera como color de marca, amarillo como acento, franja tricolor fina y un cóndor (kuntur) como logo. Detalles en `frontend/README.md`.


Inicio (landing) · Login · Registro con cédula · Confirmar correo (código) · Continuar con Google · Completar cédula · Lista/búsqueda de vuelos · Detalle · Mapa de asientos y reserva (subtotal, IVA, total) · Mis reservas (ver, modificar, cancelar) · Comprobante XML · (Admin) panel de IVA, importar aviones por CSV y crear vuelo eligiendo avión.
Se ejecuta como **web** (`flutter run -d chrome`) y también puede compilarse a Android.
Paquetes: `flutter_riverpod` (estado + DI), `go_router`, `http`, `shared_preferences` (JWT), `xml`, `file_picker` (CSV), `google_sign_in` + `google_sign_in_web` (Google).

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
Excepciones documentadas: `flasgger==0.9.7.1` (la 0.9.4 no funciona con Flask 3) y `google_sign_in_web 1.1.3` (las versiones 1.1.0–1.1.2 no se pueden resolver).

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
| B7 | Comprobante XML + Swagger completo + colección Postman | ✅ Hecho |
| B8 | Robustez: validaciones de entrada, errores HTTP, límites = BD y base caída | ✅ Hecho |
| F1 | Frontend: tema Ecuador, login, registro, sesión persistente y rutas protegidas | ✅ Hecho |
| F2 | Frontend: lista paginada y búsqueda de vuelos, detalle, crear vuelo (admin), panel de administración con IVA | ✅ Hecho |
| F3 | Frontend: reservar desde el detalle, mis reservas (paginadas), modificar con versión y cancelar. **El administrador no reserva** (403 en el API, sin pantallas) | ✅ Hecho |
| F4 | Frontend: comprobante (factura legible + panel "Factura XML" con copiar) y mejoras de usabilidad con las heurísticas de Nielsen (barra de navegación inferior, logo → inicio, menú de cuenta, migas de pan, aviso al salir con cambios). Ver `docs/USABILIDAD.md` | ✅ Hecho |
| Z0 | Endurecimiento: rutas cerradas por defecto, CORS sin `*`, clave JWT ≥ 32 caracteres, asientos retirados sin borrado, pruebas reales independientes del IVA vigente | ✅ Hecho |
| Z1 | Página de inicio pública (`/`); la lista de vuelos pasa a `/vuelos` | ✅ Hecho |
| Z2 | Aviones por CSV: tabla `aviones`, revisar e importar, vuelos con `avion_id` | ✅ Hecho |
| Z3 | Cédula ecuatoriana (algoritmo, única) en el registro | ✅ Hecho |
| Z4 | Correo real: código de 6 dígitos por SMTP antes de poder iniciar sesión | ✅ Hecho |
| Z5 | Inicio de sesión con Google + completar la cédula | ✅ Hecho |
| P | Pruebas funcionales y capturas | Parcial: pruebas automáticas y recorrido manual hechos; faltan capturas de las pantallas nuevas |
| D | Diagrama SOA + informe PDF | Pendiente |

## 9. Decisiones pendientes

- Datos de los integrantes del grupo.
- **Despliegue (decidido):** solo el backend irá a la nube (Render); el Flutter se queda en local. Eso implica
  `CORS_ORIGINS=http://localhost:8080`, `--dart-define=API_BASE_URL=https://<servicio>.onrender.com/api` en el frontend,
  las variables `SMTP_*` y `GOOGLE_CLIENT_ID` en Render, `gunicorn` en `requirements.txt` y (opcional) un Dockerfile.
  El plan gratuito de Render duerme el servicio y la primera petición tarda ~30–60 s.
- Pagos (p. ej. PayPal) **no** se implementan: queda fuera de alcance.
