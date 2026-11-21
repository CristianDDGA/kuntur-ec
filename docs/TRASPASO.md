# Traspaso: tareas que faltan (Kuntur EC)

El sistema (backend Flask + frontend Flutter web + Supabase) está completo y probado
(pytest 646, flutter test 429, analyze sin avisos). Incluye lo pedido por el docente: aviones por CSV, cédula,
página de inicio, correo real con código e inicio de sesión con Google. Lo que queda son entregables.

## Reglas del equipo
- Commits **sin** coautoría/firma de ninguna IA. Ramas `feature/*`; el usuario abre y fusiona el PR a `develop`.
- Dependencias: usar la antepenúltima versión estable.
- Frontend con MVC (models/services/controllers/pages/widgets), Riverpod + go_router.
- La base es Supabase **real**: no crear IVA, vuelos, aviones ni cuentas de prueba sin borrarlos después. Los tests automáticos
  de la base real limpian lo que crean; las pruebas manuales deben hacerlo a mano.
- No poner credenciales en el repositorio.

## Pendiente
1. Informe + diagrama SOA.
2. **Despliegue del backend en Render** (el Flutter se queda en local): ver `docs/PLANIFICACION.md` sección 9 y la
   tabla de variables del `README.md`. Falta `gunicorn` en `requirements.txt`; Dockerfile opcional.
3. Capturas de las pantallas nuevas (`docs/PRUEBAS.md`, recorrido 20–27).
4. Opcional: descarga del comprobante; borrar vuelos de prueba (confirmar antes).

## Cuentas externas que usa el proyecto (no están en el repositorio)
- **Gmail** (envío del código): contraseña de aplicación en `backend/.env` (`SMTP_*`). Se revoca en `myaccount.google.com/apppasswords`.
- **Google Cloud**, proyecto «Kuntur EC» (`kuntur-ec`): cliente OAuth web con el origen `http://localhost:8080`, app en modo de
  prueba (solo entran los usuarios de prueba). Si el Flutter se sirve en otro puerto hay que agregar ese origen.

## Hecho en la revisión final
- Cierre automático de sesión al vencer el JWT (temporizador + aviso en el login) y vuelta a la pantalla anterior al reingresar.
- Recargar la página ya no pierde la pantalla actual.
- Paleta nueva (azul pizarra, ámbar, ladrillo, fondo cálido), íconos y manifest de la web, semántica de accesibilidad activada.
- Contraste del botón desactivado y del `SegmentedButton` seleccionado.
