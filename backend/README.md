# Backend · API REST (Flask + Clean Architecture)

## Capas y regla de dependencias

```
presentation  ──▶  application  ──▶  domain  ◀──  infrastructure
 (Flask, HTTP)     (casos de uso)    (núcleo)      (PostgreSQL, bcrypt, JWT)
```

Las flechas indican “depende de”. **El dominio no importa nada de las otras capas.**

| Capa | Carpeta | Contiene | No puede |
|---|---|---|---|
| Dominio | `src/domain/` | Entidades (`Usuario`, `Vuelo`, `Reserva`, `Token`), reglas de negocio, interfaces de repositorios, excepciones | Importar Flask, psycopg, bcrypt… |
| Aplicación | `src/application/` | Casos de uso (1 clase = 1 acción), DTOs de entrada/salida, *ports* (`PasswordHasher`, `TokenProvider`, `UnitOfWork`) | Conocer HTTP o SQL |
| Infraestructura | `src/infrastructure/` | Configuración, conexión a Supabase, repositorios PostgreSQL, bcrypt, JWT | Contener reglas de negocio |
| Presentación | `src/presentation/api/` | Blueprints por servicio, validación de entrada, serializadores JSON/XML, manejo de errores, Swagger | Acceder a la BD directamente |
| Composition root | `src/container.py` | Conecta implementaciones concretas con casos de uso | — |

## SOLID aplicado

- **SRP:** `RegistrarUsuario`, `IniciarSesion`, `CrearReserva`… cada uno hace una sola cosa.
- **OCP:** formatos de respuesta como estrategias (`JsonSerializer`, `XmlSerializer`); agregar uno no modifica los demás.
- **LSP:** `PostgresUsuarioRepository` y `InMemoryUsuarioRepository` (pruebas) son intercambiables.
- **ISP:** una interfaz de repositorio por agregado, con solo los métodos necesarios.
- **DIP:** los casos de uso reciben abstracciones por constructor; `container.py` inyecta las concretas.

## Estructura

```
backend/
├─ run.py                      # punto de entrada
├─ requirements.txt  .env.example  pytest.ini
├─ sql/                        # schema.sql, seed.sql (Supabase)
├─ src/
│  ├─ container.py             # inyección de dependencias
│  ├─ domain/
│  │  ├─ entities/             # dataclasses con reglas de negocio
│  │  ├─ repositories/         # interfaces (ABC)
│  │  └─ exceptions.py
│  ├─ application/
│  │  ├─ dtos/
│  │  ├─ ports/                # PasswordHasher, TokenProvider, UnitOfWork
│  │  └─ use_cases/{usuarios,auth,vuelos,reservas}/
│  ├─ infrastructure/
│  │  ├─ config/settings.py
│  │  ├─ persistence/          # conexión + repositories/ (PostgreSQL)
│  │  └─ security/             # bcrypt, JWT
│  └─ presentation/api/
│     ├─ app_factory.py        # create_app
│     ├─ routes/               # un Blueprint por servicio SOA
│     ├─ schemas/              # validación de requests
│     ├─ serializers/          # JSON / XML
│     ├─ responses.py          # negociación de contenido (Accept)
│     └─ error_handlers.py     # {"error","mensaje"} + código HTTP
└─ tests/
   ├─ unit/                    # casos de uso con repos en memoria
   └─ integration/             # endpoints con el cliente de Flask
```

## Comandos

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python run.py                 # http://localhost:5000/api/health  ·  Swagger: /api/docs/
pytest -q
```
