# Colección de Postman · Kuntur EC

`KunturEC.postman_collection.json` contiene las pruebas funcionales de los servicios (60 peticiones, 125 comprobaciones
`pm.test`; casos de éxito y de error 400 / 401 / 403 / 404 / 409 / 415).

## Cómo usarla

1. Levantar el backend: `cd backend` → `.venv\Scripts\python app.py`.
   **Recomendado: arrancarlo sin las variables `SMTP_*`** (por ejemplo con otro `.env` o vaciándolas en esa terminal).
   Así el código de verificación queda en el log y no se envían correos reales a direcciones de prueba.
2. Preparar el cliente de las pruebas (una vez; es idempotente):

   ```bash
   cd backend
   .venv\Scripts\python ..\docs\postman\preparar_cliente.py
   ```

   Crea `cliente.postman@kuntur.test` (contraseña `Clave2026`) **ya verificado y con cédula**. Es necesario porque una
   cuenta recién registrada no puede iniciar sesión hasta confirmar el código que llega por correo, y ese código no se
   puede automatizar. Para quitarlo: `preparar_cliente.py --borrar`.
3. En Postman: **Import** → elegir `KunturEC.postman_collection.json`.
4. Abrir la colección → **Run** (Collection Runner) → **Run Kuntur EC** sin cambiar el orden.

Cada petición guarda en variables de la colección lo que usa la siguiente
(`token_cliente`, `token_admin`, `vuelo_id`, `reserva_id`, `reserva_version`, `avion_id`…).
El registro genera un correo y una **cédula válida (módulo 10)** nuevos en cada ejecución, y el CSV de aviones una
matrícula nueva, así se puede correr varias veces.

| Carpeta | Qué prueba |
|---|---|
| 0. Sistema | Health y conexión a la base |
| 1. Usuarios | Registro con cédula (queda **sin verificar**), correo repetido, **cédula repetida**, **cédula con el verificador mal**, falta la cédula, contraseña débil, campo faltante, cuerpo no JSON |
| 2. Autenticación | Login incorrecto, **login sin verificar el correo (403)**, **verificar con código incorrecto o mal formado (400)**, **reenviar código (responde igual exista o no la cuenta)**, login cliente y admin, perfil con y sin token |
| 3. Vuelos | Búsqueda con filtros y paginación, fecha inválida, detalle, 404, crear (401/403/201/409) |
| 4. Reservas | Crear, sin asientos (409), fuera de rango, sin token, listar, detalle, **el administrador no reserva (403)**, **factura XML**, versión correcta y vieja (409), cancelar y cancelar otra vez, asientos devueltos |
| 5. Aviones (CSV) | Listar sin token/como cliente, **revisar un CSV con errores (error por línea, no guarda)**, importar con errores (400), tipo que no es `text/csv` (415), importar correcto (201), importar otra vez (se omite), listar con su capacidad, **crear un vuelo con el avión** (la capacidad sale del avión) y con un avión inexistente (404) |
| 6. Cédula y Google | Completar la cédula (401 / 403 admin / 400 inválida / 409 ya tiene), Google sin `id_token` (400) y con un token inventado (401 o 503) |
| 7. Cierre de sesión | Logout y token revocado (401) |

> **Qué no se puede automatizar:** el código real de verificación llega por correo, y el inicio con Google necesita
> una ventana de Google. Esos caminos felices se prueban a mano en la app y con las pruebas automáticas del backend
> (`pytest`) y del frontend (`flutter test`); aquí se cubren los caminos de error.

> `base_url` es `http://localhost:5000/api`; cambiarla en las variables si la API está desplegada.
> Los datos que crea la colección (cuenta `nuevo.…@kuntur.test`, vuelos `PM…` y de prueba con avión, aviones `PM-…`,
> reservas) **quedan en la base**; bórrelos si usa la base real compartida.
