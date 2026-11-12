# Pruebas de Kuntur EC

## 1. Pruebas automáticas

| Capa | Herramienta | Resultado |
|---|---|---|
| Backend (API, servicios, concurrencia, XML, IVA) | `pytest` | 516 pruebas, todas pasan (incluye pruebas contra la base real) |
| Frontend (pantallas, router, sesión, formularios) | `flutter test` | 347 pruebas, todas pasan |
| Análisis estático | `flutter analyze` | Sin avisos |
| API manual | Postman (`docs/postman/`) | Colección con casos 2xx y de error (400/401/403/404/409) |

Pruebas destacadas: reservas simultáneas sobre el mismo asiento (un solo ganador), contador de asientos
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
| Accesibilidad web | Semántica activada para lectores de pantalla |
