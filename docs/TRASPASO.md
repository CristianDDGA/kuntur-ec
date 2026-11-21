# Traspaso del proyecto (Kuntur EC)

Documento para retomar el proyecto con cualquier herramienta o persona. El sistema está **completo y probado**; lo que
queda son entregables y decisiones (sección 5).

## 1. Estado

Sistema de reservas de vuelos con **SOA**: API REST **Flask** (MVC) + cliente **Flutter web** + **Supabase** (PostgreSQL).
Rama `develop` al día con todo lo hecho (PR #1–#17). Pruebas: **pytest 646**, **flutter test 429**, `flutter analyze` sin avisos.

Hecho (detalle en `docs/PLANIFICACION.md`, sección 8):
- Núcleo: usuarios, JWT, vuelos, reservas con asientos concretos y concurrencia, IVA con historial, comprobante XML.
- Pedido por el docente: **aviones por CSV**, **cédula** (módulo 10), **página de inicio**, **correo real** (código de 6 dígitos
  por SMTP) e **inicio de sesión con Google**.
- Endurecimiento: rutas cerradas por defecto, CORS sin `*`, clave JWT ≥ 32 caracteres, límites de largo = columnas de la BD.
- Documentación al día: `README.md`, `backend/README.md`, `frontend/README.md`, `docs/PRUEBAS.md`, `docs/USABILIDAD.md`,
  `docs/PRIVACIDAD.md`, colección de Postman (`docs/postman/`, 125 comprobaciones, verificada).

**Trabajo en rama `feature/redeno-landing-vuelos` (pendiente de PR a `develop`):**
- `InicioPage` (`frontend/lib/pages/inicio_page.dart`): nueva portada comercial orientada al cliente (sin textos técnicos, sin buscador en la portada ni pill `Ecuador · USD $`), con el carrusel de las 4 regiones del Ecuador arriba, banner de experiencia y destinos populares.
- `CompletarCedulaPage` (`frontend/lib/pages/completar_cedula_page.dart`) y `backend/services/usuario_service.py`: muestra nombre precargado de Google (editable; solo se envía en `PUT /usuarios/cedula` si cambia), correo verificado y cédula; `PanelAutenticacion` ahora incluye regreso al inicio.
- `Formatos.dinero` (`frontend/lib/models/vuelo.dart`): formato `Símbolo + Espacio + Miles con coma + Decimales con punto` (ej. `$ 10,000.00`).
- Mejoras de tarjetas (`tarjeta_vuelo.dart`, `tarjeta_reserva.dart`), ancho web (`kuntur_scaffold.dart` a 980 px), `reserva_detalle_page.dart` y `comprobante_page.dart` (botón `Volver a reserva`, `Copiar XML` y `Descargar factura (XML)`).
- Pruebas verificadas en esta rama: `pytest` **646** pasadas, `flutter test` **429** pasadas, `flutter analyze` sin avisos.

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
  de página principal y privacidad en *Información de la marca* (sin logo). Sigue en modo **«Prueba»**: falta confirmar el cambio a
  «En producción» en *Público* (ver el punto 5.1).
- **Estado de la base al cerrar:** solo el administrador (`database/seed.sql`), 12 vuelos, 0 aviones, 0 reservas, IVA vigente 12 %.
  Los vuelos `KT702` y `KT703` son de pruebas del autor; el IVA 12 % también lo programó él.

## 5. Pendiente
1. **Google para cualquier cuenta.** Hay que pasar la app de «Prueba» a «En producción» (Google Cloud → Google Auth Platform →
   Público). Las URLs públicas (`https://github.com/CristianDDGA/kuntur-ec` y
   `https://github.com/CristianDDGA/kuntur-ec/blob/develop/docs/PRIVACIDAD.md`) ya están guardadas en *Información de la marca* (sin
   logo); resta confirmar la publicación. Riesgo: Google puede exigir un dominio propio; si lo rechaza, alternativas: agregar usuarios
   de prueba (hasta 100) o una página propia (p. ej. GitHub Pages). La app solo pide permisos básicos (sin verificación de Google).
2. **Informe PDF con diagrama SOA** (entregable principal de la guía APE 4) y **capturas** de las pantallas nuevas
   (`docs/PRUEBAS.md`, recorrido 20–27). Datos de los integrantes del grupo para la portada.
3. **Despliegue del backend en Render** (solo el backend; el Flutter se queda en local): variables `DATABASE_URL`,
   `JWT_SECRET_KEY`, `CORS_ORIGINS=http://localhost:8080`, `SMTP_*`, `GOOGLE_CLIENT_ID`; añadir `gunicorn` a `requirements.txt`;
   Dockerfile opcional; el frontend con `--dart-define=API_BASE_URL=https://<servicio>.onrender.com/api`. El plan gratuito duerme el servicio.
   Antes de publicar, cambiar la contraseña del administrador de `seed.sql`.
4. **Ajustes de diseño web pendientes (continuación de `feature/redeno-landing-vuelos`):**
   - Pulir el diseño web adaptable de `VuelosPage`, `ReservasPage` y `SeleccionAsientosPage` (desglose de factura/compra más detallado en selección de asientos).
   - Mejorar `frontend/lib/widgets/migas.dart` (quitar `Center` dentro de `Wrap` y subrayado de hipervínculo para que las migas no se apilen ni parezcan links planos).
   - Implementar descarga real de archivo `.xml` en el navegador en `comprobante_page.dart` (actualmente copia al portapapeles).
   - Evaluar cargar los destinos populares de `InicioPage` desde un endpoint público de la BD (manteniendo que `app_router_test.dart` exige no llamar a la API al arrancar sin token, o actualizar la prueba).
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
