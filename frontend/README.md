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
├─ config/        app_config.dart · app_theme.dart · app_motion.dart · app_router.dart · providers.dart
├─ models/        usuario · sesion · validadores (cédula, código, correo…) · vuelo · asientos · reserva · avion · factura
├─ services/      rest_client · http_rest_client · api_error_mapper · api_exception · token_storage
│                 auth_service (login, registro, verificar correo, Google, cédula) · vuelo_service · reserva_service
│                 avion_service · iva_service · sistema_service
│                 google_proveedor (interfaz ProveedorGoogle + implementación real) · google_boton_web/_otros
├─ controllers/   sesion · login · registro · verificacion (verificar correo, reenviar código) · google
│                 completar_cedula · vuelos · vuelo_detalle · crear_vuelo · aviones (lista + importar CSV)
│                 reservar · reservas · reserva_detalle · mapa_asientos · comprobante · iva · estado_api
├─ pages/         inicio_page (landing pública) · login · registro · verificar_correo · completar_cedula · vuelos
│                 vuelo_detalle · seleccion_asientos · reservas · reserva_detalle · comprobante · admin
│                 crear_vuelo · importar_aviones · estado_api · splash · no_encontrada
└─ widgets/       panel_autenticacion · boton_google · campo_password · requisitos_password · tarjeta_vuelo
                  barra_kuntur · navegacion_principal · migas · aviso · isometric_kuntur · liquid_morph · …
test/
├─ helpers/       fakes.dart (RouteFakeRestClient) · app_helper.dart · google_falso.dart (ProveedorGoogleFalso)
├─ models/ · services/ · widgets/
├─ pages/         una por pantalla (login, registro, verificar correo, Google y cédula, importar aviones, …)
└─ app_router_test.dart   arranque, rutas protegidas y cierre de sesión
```

## Pantallas y rutas

| Ruta | Pantalla | Quién |
|---|---|---|
| `/` | Página de inicio (presenta el sistema; con sesión redirige a `/vuelos`) | Pública |
| `/login` · `/registro` | Acceso; ambas con el botón «Continuar con Google» (si está disponible) | Pública |
| `/verificar-correo` | «Confirme su correo»: código de 6 dígitos, reenvío con cuenta atrás de 60 s | Solo con una cuenta pendiente (si no, va a `/login`) |
| `/completar-cedula` | «Complete su perfil»: pide la cédula; no se puede saltar | Clientes sin cédula |
| `/estado` | Estado del servicio y de la base | Pública |
| `/vuelos` · `/vuelos/:id` · `/vuelos/:id/asientos` | Búsqueda, detalle y mapa de asientos | Con sesión |
| `/reservas` · `/reservas/:id` · `/reservas/:id/comprobante` | Mis reservas, detalle, factura y XML | Clientes |
| `/admin` · `/admin/vuelos/nuevo` · `/admin/aviones/importar` | Panel (IVA), crear vuelo eligiendo avión, importar flota por CSV | Administrador |

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

- **Rutas protegidas** (`config/app_router.dart`): sin sesión solo se entra a `/`, `/login`, `/registro`,
  `/verificar-correo` y `/estado`; con sesión, esas pantallas de acceso redirigen a `/vuelos`. Mientras se valida el
  token se muestra `/cargando`. Un cliente sin cédula es llevado a `/completar-cedula` desde cualquier otra pantalla.
- **Sesión persistente:** el JWT se guarda en `SharedPreferences` (localStorage en web). Al abrir la app se valida con
  `GET /auth/perfil`; si venció o fue revocado se descarta y se pide iniciar sesión. Si el servidor no responde, el token
  se conserva (un corte de red no cierra la sesión) y se ofrece reintentar.
- **Registro y verificación del correo:** `POST /usuarios/registro` crea la cuenta **sin verificar** y la app pasa a
  `/verificar-correo`. La contraseña se guarda solo en memoria (nunca en disco) para iniciar sesión sola cuando el
  código es correcto; si se recarga la página se pierde y la persona entra a mano. Si el correo no salió, o si la
  persona llegó desde un login con `403 correo_no_verificado`, la pantalla pide un código nuevo al abrirse.
- **Inicio de sesión con Google** (`services/google_proveedor.dart`): en la web el botón lo dibuja Google (Google
  Identity Services); la app solo recibe el `id_token` y lo envía a `POST /auth/google`. El paquete queda detrás de la
  interfaz `ProveedorGoogle`, así las pruebas usan un doble (`ProveedorGoogleFalso`) sin abrir ninguna ventana. Por ahora
  solo web: Android e iOS necesitan sus propios ID de cliente y configuración nativa.
- **Cédula:** se valida con el mismo algoritmo del backend (`Validadores.cedula`) al registrarse y en «Complete su
  perfil» (`PUT /usuarios/cedula`); una vez guardada no se puede cambiar.
- **Flota (admin):** `importar_aviones_page` elige el CSV con `file_picker` (en la web se usa `pickFiles`), el servidor
  lo revisa sin guardar y se muestran la vista previa y los errores por línea; «Importar» solo se habilita con el archivo
  limpio. `crear_vuelo_page` ya no pide capacidad: se elige un avión y de él sale la cabina.
- **Cerrar sesión:** revoca el token en el servidor y borra el local; si el servidor no responde, la sesión local se cierra igual.
- **Validaciones** (`models/validadores.dart`): reflejan las del backend (lista blanca: nombres solo con letras, correo ASCII,
  contraseña de 8 a 128 caracteres con letras y números, largos iguales a las columnas de la BD). El servidor vuelve a validar todo.
- **Errores:** los mensajes de la API (`{"error","mensaje"}`) se muestran tal cual; cualquier excepción inesperada se
  oculta tras "Ocurrió un error inesperado" (nunca detalles técnicos).
- Los controladores llaman a `SesionController.sesionExpirada()` si una petición responde 401.
- Limitación conocida: el JWT en localStorage es legible por cualquier script de la página (riesgo XSS); para el alcance
  del proyecto se acepta y se documenta.

## Comandos

```bash
flutter pub get
flutter run -d chrome                                  # usa http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=https://mi-api/api
flutter run -d chrome --dart-define=GOOGLE_CLIENT_ID=<id>.apps.googleusercontent.com   # vacío = sin botón de Google
flutter analyze
flutter test
```

> **Google en local:** el cliente OAuth debe tener `http://localhost:<puerto>` como «origen autorizado de JavaScript»
> (hoy `http://localhost:8080`; con otro puerto hay que agregarlo en Google Cloud). Mientras la app esté en modo de
> prueba solo entran las cuentas agregadas como «usuarios de prueba».
