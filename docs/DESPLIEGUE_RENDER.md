# Despliegue del backend en Render

Solo se publica el **backend** (Flask). La base ya está en Supabase y el cliente Flutter se sigue ejecutando en local
(`flutter run -d chrome --web-port=8080`) apuntando a la URL de Render.

## Qué se preparó en el repositorio
| Archivo | Para qué |
|---|---|
| `render.yaml` | Describe el servicio (plano de Render): build, comando de inicio, variables y *health check* |
| `backend/wsgi.py` | Punto de entrada `wsgi:app` que usa gunicorn |
| `backend/requirements.txt` | Incluye `gunicorn==26.2.0` (antepenúltima estable) |
| `backend/config.py` | Lee el puerto de `PORT` (lo asigna Render); en local sigue `APP_PORT` |
| `backend/cambiar_clave_admin.py` | Cambia la contraseña del administrador (la del `seed.sql` es pública) |

Comando de inicio: `gunicorn wsgi:app --workers 1 --threads 4 --timeout 60 --bind 0.0.0.0:$PORT`. Se usa **1 proceso con 4 hilos**
porque cada proceso abre un pool de hasta 5 conexiones y Supabase gratis permite 15.

## Pasos (los hace el dueño de las cuentas; no se guardan secretos en el repositorio)
1. **(Recomendado, opcional en un proyecto educativo)** Cambiar la contraseña del administrador de la base real, porque la del
   `seed.sql` es pública en el repositorio y cualquiera podría entrar como administrador a la API publicada:
   `cd backend` y `.venv\Scripts\python cambiar_clave_admin.py` (se pide por teclado y cierra sus sesiones).
2. Render → **New → Blueprint** → elegir el repositorio y la rama `main` (o `develop`). Render lee `render.yaml`.
3. Completar las variables marcadas `sync: false`:
   - `DATABASE_URL`: URI del *Session pooler* de Supabase (la misma de `backend/.env`).
   - `SMTP_USER`, `SMTP_PASSWORD` (contraseña de aplicación de Gmail) y `SMTP_FROM`.
   - `GOOGLE_CLIENT_ID`: el ID de cliente OAuth web (no es secreto).
   - `JWT_SECRET_KEY` la genera Render sola (≥ 32 caracteres). `CORS_ORIGINS` ya vale `http://localhost:8080`.
4. Esperar el despliegue y abrir `https://<servicio>.onrender.com/api/health` (debe responder `estado: ok`) y `/api/docs/` (Swagger).
5. Ejecutar el Flutter contra la nube: el frontend ya trae por defecto `https://kuntur-ec-api.onrender.com/api` en
   `frontend/lib/config/app_config.dart` (la URL local quedó comentada), así que basta `flutter run -d chrome --web-port=8080`.
   Si el servicio tiene otro nombre, cambiar esa URL o pasar `--dart-define=API_BASE_URL=https://<servicio>.onrender.com/api`.

## Cosas a tener en cuenta
- **Plan gratuito:** el servicio se duerme tras ~15 min sin uso; la primera petición tarda 30–60 s. Antes de la demostración, abrir
  `/api/health` para despertarlo.
- Si cambia el origen del frontend (otro puerto o dominio), actualizar `CORS_ORIGINS` (lista separada por comas, sin `*`).
- El arranque **falla a propósito** si faltan `DATABASE_URL`, `JWT_SECRET_KEY` o `SMTP_*` con `APP_ENV=production`: se ve en *Logs*.
- Los cambios de esquema se aplican a Supabase con `python database.py` desde `backend/`, no desde Render.
- No hay datos de prueba que borrar al desplegar: Render usa la misma base de Supabase.

## Lista de comprobación
- [ ] (Opcional) Contraseña del administrador cambiada.
- [ ] `/api/health` responde `ok` en Render.
- [ ] Registro con código por correo funciona (llega el correo).
- [ ] Inicio de sesión con Google funciona desde `http://localhost:8080`.
- [ ] Un vuelo se reserva y se descarga el comprobante.
