# Frontend · Flutter (Clean Architecture por features)

Cliente (consumidor SOA) de la API REST de **Kuntur EC**. Corre en **web** (`flutter run -d chrome`) y Android.

## Capas por feature

```
presentation  ──▶  domain  ◀──  data
 (pages, widgets,   (entities,    (models, datasources remotos,
  providers)         usecases,     implementación de repositorios)
                     repos abstr.)
```

- **domain:** Dart puro. Entidades, contratos de repositorio y casos de uso. No importa Flutter ni `http`.
- **data:** modelos (`fromJson`, validan el contrato), *datasources* que dependen de la interfaz `RestClient`, repositorios que implementan los contratos del dominio.
- **presentation:** pantallas, widgets y *providers* de Riverpod (estado + inyección de dependencias).

## Estructura

```
lib/
├─ main.dart                 # inicializa SharedPreferences y lo inyecta
├─ core/
│  ├─ config/      app_config.dart (API_BASE_URL vía --dart-define)
│  ├─ di/          providers.dart (composition root de core)
│  ├─ error/       failures.dart (Server, Unauthorized, Network, InvalidResponse)
│  ├─ network/
│  │  ├─ rest_client.dart        # interfaz RestClient + asJsonMap/asJsonList
│  │  ├─ http_rest_client.dart   # implementación con package:http (JWT, timeout)
│  │  └─ api_error_mapper.dart   # respuesta de error -> Failure
│  ├─ router/      app_router.dart (go_router)
│  ├─ storage/     token_storage.dart (interfaz + SharedPreferences inyectado)
│  ├─ theme/       app_theme.dart
│  └─ widgets/     componentes compartidos
└─ features/
   ├─ sistema/     estado de la API (/health) — ejemplo completo de las 3 capas
   ├─ auth/        login, registro, logout
   ├─ vuelos/      búsqueda, detalle, crear vuelo (admin)
   └─ reservas/    reservar, mis reservas, modificar/cancelar, comprobante XML
       ├─ data/{datasources,models,repositories}
       ├─ domain/{entities,repositories,usecases}
       └─ presentation/{pages,providers,widgets}
```

## SOLID aplicado

- **SRP:** `HttpRestClient` solo transporta; `ApiErrorMapper` solo traduce errores; un caso de uso por acción.
- **OCP / LSP:** repositorios, datasources, `RestClient` y `TokenStorage` son interfaces; en pruebas se sustituyen por *fakes* que las implementan.
- **ISP:** cada interfaz expone solo lo que su consumidor necesita.
- **DIP:** la UI depende de casos de uso y los datasources de `RestClient`; las implementaciones se inyectan con Riverpod (`overrides` en pruebas).

## Comandos

```bash
flutter pub get
flutter run -d chrome                                  # usa http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=https://mi-api/api
flutter analyze
flutter test
```
