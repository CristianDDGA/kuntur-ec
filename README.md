# APE 4 · Sistema distribuido de reservas de vuelos (SOA)

Aplicación distribuida basada en Arquitectura Orientada a Servicios (SOA) para la asignatura
**Aplicaciones Distribuidas** (UTA, ciclo julio–diciembre 2026).

| Componente | Tecnología | Carpeta |
|---|---|---|
| Proveedor de servicios (API REST) | Python · Flask · Clean Architecture | [`backend/`](backend/) |
| Consumidor (cliente) | Flutter (web y móvil) · Clean Architecture | [`frontend/`](frontend/) |
| Base de datos | Supabase (PostgreSQL en la nube) | [`backend/sql/`](backend/sql/) |
| Documentación | Planificación, diagramas, pruebas, informe | [`docs/`](docs/) |

## Principios de diseño

- **Clean Architecture:** las dependencias apuntan siempre hacia el dominio.
  `presentation → application → domain ← infrastructure`
- **SOLID:**
  - **S** – cada caso de uso es una clase con una sola responsabilidad.
  - **O** – nuevos servicios o formatos (JSON/XML) se agregan sin modificar los existentes.
  - **L** – las implementaciones de repositorios son intercambiables (PostgreSQL, en memoria para pruebas).
  - **I** – interfaces pequeñas por agregado (`UsuarioRepository`, `VueloRepository`, …).
  - **D** – los casos de uso dependen de abstracciones; la inyección se hace en un único *composition root*.

## Arranque rápido

```bash
# Backend
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python run.py            # http://localhost:5000/api/health

# Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

Ver la planificación completa en [`docs/PLANIFICACION.md`](docs/PLANIFICACION.md).
