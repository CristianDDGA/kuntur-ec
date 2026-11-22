# Traspaso del proyecto (Kuntur EC)

Documento para retomar el proyecto con cualquier herramienta o persona. El sistema está **completo y probado**; lo que
queda son entregables y decisiones (sección 5).

## 1. Estado

Sistema de reservas de vuelos con **SOA**: API REST **Flask** (MVC) + cliente **Flutter web** + **Supabase** (PostgreSQL).
Rama `develop` al día con todo lo hecho hasta el PR #20; la rama `feature/pendientes-final` está pendiente de PR. Pruebas: **pytest 651**, **flutter test 430**, `flutter analyze` sin avisos.

Hecho (detalle en `docs/PLANIFICACION.md`, sección 8):
- Núcleo: usuarios, JWT, vuelos, reservas con asientos concretos y concurrencia, IVA con historial, comprobante XML.
- Pedido por el docente: **aviones por CSV**, **cédula** (módulo 10), **página de inicio**, **correo real** (código de 6 dígitos
  por SMTP) e **inicio de sesión con Google**.
- Endurecimiento: rutas cerradas por defecto, CORS sin `*`, clave JWT ≥ 32 caracteres, límites de largo = columnas de la BD.
- Documentación al día: `README.md`, `backend/README.md`, `frontend/README.md`, `docs/PRUEBAS.md`, `docs/USABILIDAD.md`,
  `docs/PRIVACIDAD.md`, colección de Postman (`docs/postman/`, 125 comprobaciones, verificada).

**Rediseño de la portada (ya en `develop`, PR #19):**
- `InicioPage` (`frontend/lib/pages/inicio_page.dart`): nueva portada comercial orientada al cliente (sin textos técnicos, sin buscador en la portada ni pill `Ecuador · USD $`), con el carrusel de las 4 regiones del Ecuador arriba, banner de experiencia y destinos populares.
- `CompletarCedulaPage` (`frontend/lib/pages/completar_cedula_page.dart`) y `backend/services/usuario_service.py`: muestra nombre precargado de Google (editable; solo se envía en `PUT /usuarios/cedula` si cambia), correo verificado y cédula; `PanelAutenticacion` ahora incluye regreso al inicio.
- `Formatos.dinero` (`frontend/lib/models/vuelo.dart`): formato `Símbolo + Espacio + Miles con coma + Decimales con punto` (ej. `$ 10,000.00`).
- Mejoras de tarjetas (`tarjeta_vuelo.dart`, `tarjeta_reserva.dart`), ancho web (`kuntur_scaffold.dart` a 980 px), `reserva_detalle_page.dart` y `comprobante_page.dart` (botón `Volver a reserva`, `Copiar XML` y `Descargar factura (XML)`).

**Diseño web adaptable (rama `feature/ajuste-ancho-web`, pendiente de PR a `develop`):** ancho de contenido 1200 px (portada 1240 px),
barra de desplazamiento en el borde de la ventana, `RejillaAdaptable` (2 columnas en `VuelosPage`/`ReservasPage`, hasta 4 en la portada),
carrusel a pantalla completa con foto por región, `migas.dart` corregido y descarga real del XML (`services/descarga_web.dart`).
Las fotos de `frontend/assets/regiones/` (`sierra.jpg`, `costa.jpg`, `oriente.jpg`, `galapagos.jpg`) son el fondo del carrusel; se pueden
reemplazar por otras con el mismo nombre. Si falta alguna, se ve el degradado. Detalle para el informe en `docs/USABILIDAD.md` y fila Z7 de `docs/PLANIFICACION.md`. 

**Pendientes finales (rama `feature/pendientes-final`):** destinos de la portada desde la BD (`GET /api/vuelos/destinos`, público; con respaldo si la API
no responde) y **resumen de ventas** del administrador (`GET /api/reservas/resumen` + tarjeta en `AdminPage`). Pruebas finales: pytest **651**, flutter test **430**, `flutter analyze` limpio.

## 2. Cómo correrlo

```bash
# Backend (http://localhost:5000/api/health · Swagger /api/docs/)
cd backend && .venv\Scripts\python app.py
# Frontend: DEBE ser el puerto 8080 (es el único origen autorizado en Google)
cd frontend && flutter run -d chrome --web-port=8080
# Pruebas
cd backend && .venv\Scripts\python -m pytest -q
cd frontend && flutter analyze && flutter test
```

Configuración en `backend/.env` (plantilla en `backend/.env.example`; **nunca subirlo**): `DATABASE_URL`, `JWT_SECRET_KEY`,
`CORS_ORIGINS`, `SMTP_*`, `GOOGLE_CLIENT_ID`. Tabla completa en el `README.md`. El `.env` real ya está en el equipo del autor.

Ejemplo para probar la importación de aviones: `docs/ejemplos/aviones.csv` (formato `matricula;modelo;filas`).

## 3. Reglas del equipo
- Commits **sin** coautoría ni firma de ninguna IA (ni `Co-Authored-By` ni «Generated with…»); tampoco menciones en código o informe.
- Ramas `feature/*` desde `develop`; el **usuario** hace commit, push y abre/fusiona el PR a `develop`.
- Dependencias: fijar la **antepenúltima** versión estable (excepciones documentadas en `PLANIFICACION.md`, sección 7).
- Frontend: MVC (`models/services/controllers/pages/widgets`), Riverpod + go_router. Backend: `routes → services → models`.
- Toda columna `VARCHAR` nueva necesita su límite en `backend/utils/limites.py` (lo verifica una prueba).
- La base es **Supabase real**: no dejar datos de prueba; borrar lo que se cree a mano. Las pruebas automáticas limpian lo suyo.
- No poner credenciales en el repositorio ni en los documentos.

## 4. Cuentas y servicios externos (fuera del repositorio)
- **Supabase:** proyecto «Kuntur EC»; conexión por *Session pooler* (plan gratuito: 15 conexiones).
- **Gmail:** contraseña de aplicación para enviar el código (`SMTP_*`). Se revoca en `myaccount.google.com/apppasswords`.
- **Google Cloud**, proyecto «Kuntur EC» (`kuntur-ec`): cliente OAuth web con el origen `http://localhost:8080`. Ya se guardaron las URLs
  de página principal y privacidad en *Información de la marca* (sin logo). Ya está **«En producción»** (publicada el 2026-11-21 en
  *Público*, sin pedir verificación); falta probarla con otras cuentas (ver el punto 5.1).
- **Estado de la base al cerrar:** solo el administrador (`database/seed.sql`), 12 vuelos, 0 aviones, 0 reservas, IVA vigente 12 %.
  Los vuelos `KT702` y `KT703` son de pruebas del autor; el IVA 12 % también lo programó él.

## 5. Pendiente
1. **Google para cualquier cuenta (publicada, falta probar).** La app ya pasó de «Prueba» a «En producción» (Google Cloud → Google
   Auth Platform → Público) y no pidió verificación. Las URLs públicas (`https://github.com/CristianDDGA/kuntur-ec` y
   `https://github.com/CristianDDGA/kuntur-ec/blob/develop/docs/PRIVACIDAD.md`) están en *Información de la marca* (sin logo). Falta
   comprobar el inicio de sesión con cuentas distintas (punto 6). Si Google llegara a exigir un dominio propio, alternativas: volver al
   modo de prueba y agregar usuarios (hasta 100) o una página propia (p. ej. GitHub Pages). La app solo pide permisos básicos.
2. **Informe PDF con diagrama SOA** (entregable principal de la guía APE 4) y **capturas** de las pantallas nuevas
   (`docs/PRUEBAS.md`, recorrido 20–27). Datos de los integrantes del grupo para la portada.
3. **Despliegue del backend en Render:** el repositorio ya está preparado (`render.yaml`, `backend/wsgi.py`, gunicorn, `PORT`,
   `backend/cambiar_clave_admin.py`). Solo falta que el dueño de las cuentas siga `docs/DESPLIEGUE_RENDER.md`: cambiar la clave del
   administrador, crear el Blueprint en Render, completar `DATABASE_URL`, `SMTP_*` y `GOOGLE_CLIENT_ID`, y probar `/api/health`.
4. **Ajustes de diseño web pendientes:** desglose de factura/compra más detallado en `SeleccionAsientosPage`.
5. Opcionales: editar/cancelar vuelos, historial de cambios de reservas, total esperado antes de reservar, resumen de ventas,
   pruebas de concurrencia automáticas, login con Google en Android.
6. **Antes de la demostración:** ensayo con 2 o 3 cuentas de Google distintas, cada una con una cédula válida diferente; el Flutter
   siempre en el puerto 8080; plan B = registro normal (cédula + código por correo), que no depende de Google.

## 6. Trampas conocidas
- `flutter build web`: si un plugin nuevo no entra al build (p. ej. `file_picker`), borrar `frontend/.dart_tool/flutter_build`. Al probar en el
  navegador, quitar el *service worker* y la caché o se ve la versión vieja.
- En la web, `file_picker` se usa con `pickFiles` (el singular no funciona). El botón de Google lo dibuja Google; los popups de Google solo
  se abren con clic del usuario, no con automatización.
- Una cuenta sin cédula (p. ej. creada con Google) es enviada a «Complete su perfil» antes de poder usar la app.
- Las pruebas **nunca** envían correos reales (usan `EnviadorLocal`); el servidor real sí, si tiene `SMTP_*`.
- En Windows, consola con emojis: ejecutar scripts con `PYTHONIOENCODING=utf-8`. Los procesos `app.py` huérfanos se cierran desde el administrador de tareas.
