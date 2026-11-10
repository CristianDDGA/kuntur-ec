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
├─ config/        app_config.dart · app_theme.dart (paleta Ecuador) · app_router.dart · providers.dart
├─ models/        usuario.dart · sesion.dart · validadores.dart · estado_servicio.dart
├─ services/      rest_client.dart · http_rest_client.dart · api_error_mapper.dart · api_exception.dart
│                 token_storage.dart · auth_service.dart · sistema_service.dart
├─ controllers/   sesion_controller.dart · login_controller.dart · registro_controller.dart
│                 estado_api_controller.dart
├─ pages/         login_page.dart · registro_page.dart · inicio_page.dart · splash_page.dart
│                 estado_api_page.dart
└─ widgets/       panel_autenticacion.dart · logo_kuntur.dart · franja_tricolor.dart · boton_degradado.dart
                  campo_password.dart · requisitos_password.dart · aviso.dart
test/
├─ helpers/       fakes.dart (RouteFakeRestClient) · app_helper.dart
├─ models/        validadores · usuario y sesión
├─ services/      cliente HTTP, errores, token, auth_service
├─ pages/         login y registro (formularios, errores, carga)
└─ app_router_test.dart   arranque, rutas protegidas y cierre de sesión
```

## Diseño (tema Ecuador)

Parte de la estructura de APE8 (formulario centrado en una tarjeta redondeada sobre un fondo suave),
con otra paleta y pocos toques de Ecuador, sin exagerar. Todo vive en `config/app_theme.dart`
(`AppColors`, `AppGradients`, `AppTextStyles`, `AppDecorations`, `AppTheme`).

| Elemento | Detalle |
|---|---|
| Azul `#0B4DA2` | Color de marca (azul de la bandera): botones, enlaces, foco de los campos |
| Amarillo `#FFC800` | Acento: la franja tricolor y la palabra "EC" sobre la barra oscura |
| Rojo `#D62839` | Solo errores y el último tramo de la franja tricolor |
| Azul noche `#071E45` | Barra superior; texto principal `#0A2540` |
| Fondo "niebla de páramo" | Degradado suave `#E6EEF9` → `#F2F6FC` |
| Logo | Un cóndor andino (kuntur) dibujado con `CustomPaint`, sin imágenes |
| Franja tricolor | 5 px, proporción 2:1:1 de la bandera, arriba de la tarjeta y de la barra |

Un solo tema claro (los colores de marca no se invierten). Los textos pasan el contraste WCAG AA.

## Autenticación y sesión

```
LoginPage / RegistroPage ──▶ LoginController / RegistroController ──▶ AuthService ──▶ API REST
                                         │
                                         ▼
                                SesionController  (usuario actual o null)
                                         │
                                         ▼
                               appRouterProvider  (redirige según la sesión)
```

- **Rutas protegidas** (`config/app_router.dart`): sin sesión solo se entra a `/login`, `/registro` y `/estado`;
  con sesión, login y registro redirigen al inicio. Mientras se valida el token se muestra `/cargando`.
- **Sesión persistente:** el JWT se guarda en `SharedPreferences` (localStorage en web). Al abrir la app se valida con
  `GET /auth/perfil`; si venció o fue revocado se descarta y se pide iniciar sesión. Si el servidor no responde, el token
  se conserva (un corte de red no cierra la sesión) y se ofrece reintentar.
- **Registro:** crea la cuenta (`POST /usuarios/registro`) e inicia sesión de inmediato con las mismas credenciales.
- **Cerrar sesión:** revoca el token en el servidor y borra el local; si el servidor no responde, la sesión local se cierra igual.
- **Validaciones** (`models/validadores.dart`): reflejan las del backend (lista blanca: nombres solo con letras, correo ASCII,
  contraseña de 8 a 128 caracteres con letras y números, largos iguales a las columnas de la BD). El servidor vuelve a validar todo.
- **Errores:** los mensajes de la API (`{"error","mensaje"}`) se muestran tal cual; cualquier excepción inesperada se
  oculta tras "Ocurrió un error inesperado" (nunca detalles técnicos).
- Los controladores de las siguientes etapas llaman a `SesionController.sesionExpirada()` si una petición responde 401.
- Limitación conocida: el JWT en localStorage es legible por cualquier script de la página (riesgo XSS); para el alcance
  del proyecto se acepta y se documenta.

## Comandos

```bash
flutter pub get
flutter run -d chrome                                  # usa http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=https://mi-api/api
flutter analyze
flutter test
```
