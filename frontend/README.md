# Frontend · Flutter (MVC)

Cliente (consumidor SOA) de la API REST de **Kuntur EC**. Corre en **web** (`flutter run -d chrome`) y Android.

## Patrón MVC

```
pages/ + widgets/  (V)  dibujan la pantalla y envían las acciones del usuario
        │
        ▼
controllers/       (C)  manejan el estado (cargando / datos / error) y las acciones
        │
        ▼
services/               consumen la API REST (HTTP, JWT, errores)
        │
        ▼
models/            (M)  clases de datos con fromJson / toJson
```

| Carpeta | Responsabilidad | No debe |
|---|---|---|
| `config/` | Configuración (`AppConfig`), tema, rutas e inyección de dependencias (`providers.dart`) | Tener lógica de pantallas |
| `models/` | Clases inmutables con `fromJson` que validan el contrato de la API | Hacer peticiones HTTP |
| `services/` | Un servicio por recurso de la API (`SistemaService`, `AuthService`, …) sobre la interfaz `RestClient` | Conocer widgets |
| `controllers/` | `AsyncNotifier` de Riverpod por pantalla: estado + acciones | Construir widgets |
| `pages/` | Pantallas completas (`ConsumerWidget`) | Llamar a la API directamente |
| `widgets/` | Componentes reutilizables (tarjetas de vuelo, botones, etc.) | Tener estado global |

## Buenas prácticas aplicadas

- **DIP:** los servicios dependen de la interfaz `RestClient`, no de `package:http`; todo se inyecta con Riverpod y en las pruebas se reemplaza con `overrides`.
- **SRP:** `HttpRestClient` solo transporta, `ApiErrorMapper` solo traduce errores, cada controlador maneja una pantalla.
- **Sin duplicación:** un único cliente HTTP agrega el JWT y traduce errores para todos los servicios.
- **Errores tipados:** `ServerFailure`, `UnauthorizedFailure`, `NetworkFailure`, `InvalidResponseFailure`.
- **Configuración sin tocar código:** la URL de la API se pasa con `--dart-define=API_BASE_URL=...`.

## Estructura

```
lib/
├─ main.dart
├─ config/        app_config.dart · app_theme.dart · app_router.dart · providers.dart
├─ models/        estado_servicio.dart
├─ services/      rest_client.dart · http_rest_client.dart · api_error_mapper.dart
│                 api_exception.dart · token_storage.dart · sistema_service.dart
├─ controllers/   estado_api_controller.dart
├─ pages/         estado_api_page.dart
└─ widgets/
test/
├─ helpers/fakes.dart
├─ services/      cliente HTTP, errores, token, servicios
└─ pages/         pruebas de widgets
```

## Comandos

```bash
flutter pub get
flutter run -d chrome                                  # usa http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=https://mi-api/api
flutter analyze
flutter test
```
