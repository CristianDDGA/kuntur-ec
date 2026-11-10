# Colección de Postman · Kuntur EC

`KunturEC.postman_collection.json` contiene las pruebas funcionales de los 5 servicios
(36 peticiones, casos de éxito y de error 400 / 401 / 403 / 404 / 409).

## Cómo usarla

1. Levantar el backend: `cd backend` → `.venv\Scripts\python app.py`.
2. En Postman: **Import** → elegir `KunturEC.postman_collection.json`.
3. Abrir la colección → **Run** (Collection Runner) → **Run Kuntur EC** sin cambiar el orden.

Cada petición guarda en variables de la colección lo que usa la siguiente
(`token_cliente`, `token_admin`, `vuelo_id`, `reserva_id`, `reserva_version`).
El registro usa un correo nuevo en cada ejecución, así se puede correr varias veces.

| Carpeta | Qué prueba |
|---|---|
| 0. Sistema | Health y conexión a la base |
| 1. Usuarios | Registro, correo repetido, contraseña débil, campo faltante, cuerpo no JSON |
| 2. Autenticación | Login incorrecto/correcto (cliente y admin), perfil con y sin token |
| 3. Vuelos | Búsqueda con filtros, fecha inválida, detalle, 404, crear (401/403/201/409) |
| 4. Reservas | Crear, sin asientos (409), fuera de rango, sin token, listar, detalle, reserva ajena (404), **factura XML**, **versión correcta y vieja (409)**, cancelar y cancelar otra vez, asientos devueltos |
| 5. Cierre de sesión | Logout y token revocado (401) |

> `base_url` es `http://localhost:5000/api`; cambiarla en las variables si la API está desplegada.
> Los datos que crea la colección (cliente, vuelo `PM…`, reserva cancelada) quedan en la base.
