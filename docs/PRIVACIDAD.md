# Política de privacidad · Kuntur EC

**Kuntur EC** es un sistema de reservas de vuelos desarrollado como proyecto académico de la asignatura
*Aplicaciones Distribuidas* (Universidad Técnica de Ambato, ciclo julio–diciembre 2026). No tiene fines comerciales.

Esta página explica qué datos usa el sistema, para qué y cómo se protegen. Última actualización: noviembre de 2026.

## Qué datos recogemos

| Dato | De dónde viene | Para qué se usa |
|---|---|---|
| Nombre | Lo escribe la persona al registrarse, o viene de su cuenta de Google | Mostrarlo en la aplicación y en la factura de la reserva |
| Correo electrónico | Lo escribe la persona, o viene de su cuenta de Google | Identificar la cuenta, iniciar sesión y enviar el código de verificación |
| Cédula de identidad | La escribe la persona (al registrarse o al completar su perfil) | Identificar al cliente; solo se valida el número, **no se consulta ningún registro civil** |
| Contraseña | La escribe la persona (no aplica si entra solo con Google) | Iniciar sesión. **Nunca se guarda: solo se guarda un hash bcrypt** que no se puede revertir |
| Reservas (vuelo, asientos, montos) | Las crea la persona | Gestionar sus reservas y generar el comprobante |
| Identificador de la cuenta de Google (`sub`) | Google, al iniciar sesión con Google | Reconocer la cuenta en el próximo ingreso |

## Inicio de sesión con Google

Cuando una persona elige «Continuar con Google», Google le entrega a la aplicación únicamente su **nombre, su correo
electrónico (verificado) y un identificador de cuenta**. No pedimos ni recibimos acceso a Gmail, contactos, Drive,
calendario ni a ningún otro dato de su cuenta, y no guardamos su foto de perfil. La contraseña de Google nunca pasa
por Kuntur EC.

El uso de la información recibida de las API de Google se ajusta a la
[Política de datos de usuario de los servicios de las API de Google](https://developers.google.com/terms/api-services-user-data-policy),
incluidos los requisitos de uso limitado.

## Con quién se comparten los datos

**No vendemos ni cedemos datos a terceros.** Solo intervienen estos proveedores técnicos:

- **Supabase** (base de datos PostgreSQL en la nube): almacena las cuentas y las reservas.
- **Google**: para el inicio de sesión con Google y, a través de Gmail (SMTP), el envío del código de verificación al correo de la persona.

## Cómo se protegen

- Contraseñas con hash bcrypt; las sesiones usan tokens firmados que se pueden revocar al cerrar sesión.
- El código de verificación del correo se guarda cifrado (HMAC), vence a los 10 minutos y admite 5 intentos.
- Los secretos (claves de la base, del correo) viven solo en variables de entorno, nunca en el repositorio.
- La base de datos no es accesible públicamente: solo el servidor del sistema se conecta a ella.

## Cuánto tiempo se conservan

Mientras la cuenta exista. Al ser un proyecto académico, los datos de prueba se eliminan al terminar el curso.

## Sus derechos

Puede pedir ver, corregir o eliminar sus datos, o que se desvincule su cuenta de Google, abriendo una incidencia en
<https://github.com/CristianDDGA/kuntur-ec/issues>. También puede retirar el acceso de Kuntur EC a su cuenta de Google
en <https://myaccount.google.com/permissions>.

## Cambios

Si esta política cambia, se actualizará esta página con la nueva fecha.
