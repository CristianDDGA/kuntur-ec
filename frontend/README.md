# Frontend · Flutter (Clean Architecture por features)

Cliente (consumidor SOA) de la API REST. Corre en **web** (`flutter run -d chrome`) y Android.

## Capas por feature

```
presentation  ──▶  domain  ◀──  data
 (pages, widgets,   (entities,    (models JSON/XML, datasources
  providers)         usecases,     remotos, implementación de
                     repos abstr.)  repositorios)
```

- **domain:** Dart puro. Entidades, contratos de repositorio y casos de uso. No importa Flutter ni `http`.
- **data:** modelos (`fromJson`/`toJson`), *datasources* que usan `ApiClient`, repositorios que implementan los contratos del dominio y convierten errores en `Failure`.
- **presentation:** pantallas, widgets y *providers* de Riverpod (estado + inyección de dependencias).

## Estructura

```
lib/
├─ main.dart
├─ core/
│  ├─ config/      app_config.dart (API_BASE_URL vía --dart-define)
│  ├─ di/          providers.dart (http, TokenStorage, ApiClient)
│  ├─ error/       failures.dart (ServerFailure, UnauthorizedFailure, NetworkFailure)
│  ├─ network/     api_client.dart (JWT automático, JSON/XML, errores uniformes)
│  ├─ router/      app_router.dart (go_router)
│  ├─ storage/     token_storage.dart
│  ├─ theme/       app_theme.dart
│  └─ widgets/     componentes compartidos
└─ features/
   ├─ auth/        login, registro, logout
   ├─ vuelos/      búsqueda, detalle, crear vuelo (admin)
   └─ reservas/    reservar, mis reservas, modificar/cancelar, comprobante XML
       ├─ data/{datasources,models,repositories}
       ├─ domain/{entities,repositories,usecases}
       └─ presentation/{pages,providers,widgets}
```

## SOLID aplicado

- **SRP:** un caso de uso por acción (`IniciarSesion`, `BuscarVuelos`, `CrearReserva`…).
- **OCP / LSP:** los repositorios se definen como interfaces; en pruebas se reemplazan por *fakes*.
- **ISP:** `TokenStorage` y cada repositorio exponen solo lo necesario.
- **DIP:** la UI depende de casos de uso; las implementaciones se inyectan con Riverpod (`overrides` en pruebas).

## Comandos

```bash
flutter pub get
flutter run -d chrome                                  # usa http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=https://mi-api/api
flutter test
```
