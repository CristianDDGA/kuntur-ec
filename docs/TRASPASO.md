# Traspaso: tareas que faltan (Kuntur EC)

El sistema (backend Flask + frontend Flutter web + Supabase) está completo y probado
(pytest 516, flutter test 347, analyze sin avisos). Lo que queda son entregables.

## Reglas del equipo
- Commits **sin** coautoría/firma de ninguna IA. Ramas `feature/*`; el usuario abre y fusiona el PR a `develop`.
- Dependencias: usar la antepenúltima versión estable.
- Frontend con MVC (models/services/controllers/pages/widgets), Riverpod + go_router.
- La base es Supabase **real**: no crear IVA ni vuelos de prueba sin borrarlos después.
- No poner credenciales en el repositorio.

## Pendiente
1. `docs/PRUEBAS.md` ya existe; completar con las capturas faltantes.
   Faltan capturas: detalle de vuelo, mapa de asientos, reserva confirmada, página no encontrada, sesión vencida, vistas de escritorio.
2. Prueba de expiración del token: arrancar el backend con `JWT_EXPIRES_MINUTES=1`, iniciar sesión, esperar >1 min
   y comprobar que vuelve al login con el aviso "Su sesión venció por seguridad…".
5. Informe + diagrama SOA.
6. Decidir despliegue (y Docker, opcional). Opcional: descarga del comprobante; borrar vuelos de prueba (confirmar antes).

## Hecho en la revisión final
- Cierre automático de sesión al vencer el JWT (temporizador + aviso en el login) y vuelta a la pantalla anterior al reingresar.
- Recargar la página ya no pierde la pantalla actual.
- Paleta nueva (azul pizarra, ámbar, ladrillo, fondo cálido), íconos y manifest de la web, semántica de accesibilidad activada.
- Contraste del botón desactivado y del `SegmentedButton` seleccionado.
