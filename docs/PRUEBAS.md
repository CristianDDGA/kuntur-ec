# Pruebas de Kuntur EC

## 1. Pruebas automáticas

| Capa | Herramienta | Resultado |
|---|---|---|
| Backend (API, servicios, concurrencia, XML, IVA, aviones, cédula, correo, Google) | `pytest` | 692 pruebas, todas pasan (incluye pruebas contra la base real) |
| Frontend (pantallas, router, sesión, formularios, Google, importación) | `flutter test` | 451 pruebas, todas pasan |
| Análisis estático | `flutter analyze` | Sin avisos |
| API manual | Postman (`docs/postman/`) | Colección con casos 2xx y de error (400/401/403/404/409/415) |

Pruebas destacadas de las funciones nuevas:
- **Recuperación de contraseña:** responde igual con cuenta o sin ella (y aunque falle el correo); el código se guarda como huella y no
  sirve el de otra cuenta ni el del registro; 5 intentos; una contraseña floja no gasta un intento; al cambiarla se cierran las
  sesiones abiertas, el código no se reutiliza y una cuenta sin verificar queda verificada. Frontend: 11 pruebas de la pantalla.
- **Cédula:** cambiar un solo dígito de una cédula válida siempre la invalida (se prueban las 90 variantes); provincias 01–24 y 30.
- **Correo:** el código se guarda como huella (nunca en claro), vence, cuenta intentos (el intento fallido no se deshace),
  un reenvío antes de 60 s no envía nada, y todo lo que no sirve responde lo mismo sin revelar si la cuenta existe.
  Flujo completo contra la base real: registro → login bloqueado (403) → código → login.
- **Google:** el servidor usa solo lo que firma Google (un cuerpo con `correo: admin@kuntur.ec` o `rol: admin` no cambia
  nada); correo sin verificar, token ajeno o inventado → 401; cuenta existente por correo se vincula; otra cuenta de
  Google con el mismo correo → 409; la cuenta creada con Google no entra con contraseña.
- **Aviones:** el CSV con errores no importa ni una fila (todo o nada), matrículas repetidas se omiten, 413 sobre 1 MB,
  415 si no es `text/csv`; un vuelo con avión toma su capacidad y rechaza asientos fuera del avión (fila 4 en un avión de 3).
- **Seguridad:** ninguna ruta puede quedar abierta por olvido (`test_cerrado_por_defecto`); las pruebas automáticas
  **nunca envían correos reales**.

Pruebas destacadas anteriores: reservas simultáneas sobre el mismo asiento (un solo ganador), contador de asientos
atómico, modificación con versión vieja (409), token revocado tras logout (401), cierre automático de la
sesión al vencer el token, y `volver` a la pantalla anterior sin redirecciones abiertas.

## 2. Recorrido manual de la revisión final

Se recorrió la app como usuario (cliente y administrador) en vista móvil de 390×844.

| # | Caso | Resultado esperado | Estado | Captura |
|---|---|---|---|---|
| 1 | Pantalla de login | Formulario claro, enlace a registro | OK | `capturas/01-login.jpg` |
| 2 | Registro con campos vacíos/ inválidos | Error bajo cada campo y lista de requisitos de contraseña | OK | `capturas/02-registro-validacion.jpg` |
| 3 | Lista de vuelos | Vuelos con precio y asientos | OK | `capturas/03-vuelos.jpg` |
| 4 | Mis reservas | Lista de reservas del cliente | OK | `capturas/08-mis-reservas.jpg` |
| 5 | Detalle de reserva | Asientos, vuelo, totales con IVA | OK | `capturas/09-detalle-reserva.jpg` |
| 6 | Comprobante (factura) | Factura legible | OK | `capturas/10-comprobante-factura.jpg` |
| 7 | Comprobante en XML | XML con `<Asientos>` | OK | `capturas/11-comprobante-xml.jpg` |
| 8 | Menú de cuenta | Datos y cerrar sesión | OK | `capturas/12-menu-cuenta.jpg` |
| 9 | Confirmar cierre de sesión | Diálogo de confirmación | OK | `capturas/13-confirmar-cerrar-sesion.jpg` |
| 10 | Vuelos como administrador | Sin botón de reservar | OK | `capturas/14-vuelos-administrador.jpg` |
| 11 | Panel de administración | Acceso a crear vuelo e IVA | OK | `capturas/15-panel-administracion.jpg` |
| 12 | Crear vuelo con datos inválidos | Errores de validación por campo | OK | `capturas/16-crear-vuelo-validacion.jpg` |
| 13 | Detalle de vuelo | Datos del vuelo y botón «Elegir asientos» | OK | `capturas/04-detalle-vuelo.jpg` |
| 14 | Mapa de asientos (vacío) | Leyenda y asientos disponibles | OK | `capturas/05-mapa-asientos.jpg` |
| 15 | Selección de asientos | Resumen con subtotal, IVA y total | OK | `capturas/06-seleccion-asientos.jpg` |
| 16 | Reserva confirmada | Código, asientos y total | OK | `capturas/07-reserva-confirmada.jpg` |
| 17 | Dirección inexistente | Página «No encontramos esa página» | OK | `capturas/17-pagina-no-encontrada.jpg` |
| 18 | Vista de escritorio (mapa de asientos) | Contenido centrado; recargar conserva la pantalla | OK | `capturas/18-escritorio-mapa-asientos.jpg` |
| 19 | Sesión vencida | Vuelve al login con aviso | OK | `capturas/19-sesion-vencida.jpg` |

### Recorrido manual de las funciones nuevas (navegador, backend real)

Verificado el 20–21/11/2026 en el navegador contra Supabase. **Todavía no tienen captura** (pendiente para el informe).

| # | Caso | Resultado | Estado |
|---|---|---|---|
| 20 | Página de inicio y paso a login/registro | Landing pública; con sesión redirige a `/vuelos` | OK |
| 21 | Cédula `1550007998` (un dígito distinto) vs `1550007999` | La primera se rechaza al instante; la segunda se acepta | OK |
| 22 | Registro con cédula válida | Pasa a «Confirme su correo» y la cuenta existe sin verificar | OK |
| 23 | Código por correo real (Gmail) | Llega a la bandeja; al escribirlo la app verifica e inicia sesión sola | OK |
| 24 | Importar aviones: archivo con una fila errónea | Dos errores en la línea 3, vista previa de las filas válidas y «Importar» desactivado | OK |
| 25 | Importar aviones: archivo correcto | «Se importaron 3 aviones» y aparecen en la lista | OK |
| 26 | Crear un vuelo eligiendo avión | Capacidad y cabina salen del avión (ATR de 18 filas → 72 asientos) | OK |
| 27 | «Continuar con Google» con la cuenta de prueba | Crea la cuenta verificada, pide la cédula y entra a los vuelos | OK |

## 3. Expiración del token

- El token JWT lleva `exp`. La app lo lee y programa un temporizador: al vencer, descarta la sesión y
  lleva al login con el aviso *«Su sesión venció por seguridad. Inicie sesión nuevamente para continuar.»*
- Si una petición recibe 401, se aplica el mismo cierre.
- Al volver a iniciar sesión, se regresa a la pantalla donde estaba (solo rutas internas).
- Al cerrar sesión a propósito no se recuerda la pantalla.
- Cubierto por `test/pages/sesion_vencida_test.dart` y `test/app_router_volver_test.dart`.
- Verificado en el navegador real con `JWT_EXPIRES_MINUTES=1`: tras ~1 minuto la app pasó sola al login con el aviso (captura 19).

## 4. Hallazgos y correcciones

| Hallazgo | Corrección |
|---|---|
| La sesión vencida solo se notaba al fallar una petición | Cierre automático con aviso explicativo |
| Recargar la página llevaba siempre al inicio | Se respeta la dirección del navegador |
| Azul muy saturado, aspecto «tecnológico» | Paleta nueva: azul pizarra, ámbar, ladrillo y fondo cálido |
| Texto de botón desactivado poco legible | Texto oscuro sobre gris |
| Segmento seleccionado con poco contraste | Tema de `SegmentedButton` (azul con texto blanco) |
| Íconos y manifest por defecto de Flutter | Regenerados con el logo del cóndor; idioma `es` |
| Accesibilidad web | Etiquetas `Semantics` en los widgets; el árbol de semántica se activa a pedido (lector de pantalla), no al arrancar, para que los campos de texto no pierdan el primer clic |
