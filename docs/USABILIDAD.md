# Kuntur EC · Usabilidad (heurísticas de Nielsen)

Revisión de la interfaz con las 10 heurísticas de usabilidad de Jakob Nielsen y lo que se hizo con cada una.
El caso que la disparó: en el detalle de una reserva un usuario común solo tenía la flecha "Volver"; no
sabía cómo ir al inicio ni a sus reservas.

## Hallazgos y mejoras

| # | Heurística | Problema detectado | Mejora aplicada |
|---|---|---|---|
| 1 | Visibilidad del estado del sistema | El usuario no sabía en qué sección estaba. | Barra de navegación inferior con la sección resaltada y migas de pan ("Mis reservas › KEC-0058 › Comprobante"). Contadores ("12 vuelos disponibles", "Asientos 3 de 10"), indicadores de carga y avisos de éxito. |
| 2 | Relación con el mundo real | Datos técnicos o en inglés. | Todo en español; fechas "mar 1 dic 2026", horas 24 h, dinero "$75.50", asientos como en un avión (1A, 2B) con pasillo. |
| 3 | Control y libertad del usuario | Solo se podía retroceder con la flecha; no había salida clara. | Logo siempre lleva al inicio; barra inferior a cualquier sección; migas tocables; "Reiniciar selección" / "Restablecer"; aviso "¿Salir sin guardar?" al abandonar el mapa con cambios; confirmación al cancelar una reserva y al cerrar sesión. |
| 4 | Consistencia y estándares | Íconos sueltos sin texto (escudo, ticket, nube) y acciones distintas según la pantalla. | Menú de cuenta único (avatar) y barra inferior con **texto** en cada destino; misma barra superior en todas las pantallas; botones con el mismo nombre para la misma acción. |
| 5 | Prevención de errores | Se podían escribir datos fuera de rango. | Campos que no dejan escribir lo inválido (letras en precio, más de 200 asientos, emojis); máximo 10 asientos por reserva (el resto se atenúa); asientos ocupados bloqueados; botones desactivados si no hay nada que enviar; protección contra doble toque. |
| 6 | Reconocer antes que recordar | El usuario debía recordar cómo llegó. | Migas de pan, filtros que se conservan al volver, leyenda del mapa (Disponible / Seleccionado / Ocupado), resumen fijo con asientos y total. |
| 7 | Flexibilidad y eficiencia | — | Búsqueda por origen/destino/fecha, paginación, Enter envía los formularios, copiar el XML con un toque. |
| 8 | Diseño estético y minimalista | — | Una acción principal por pantalla; paleta sobria de Ecuador; el panel del administrador separado del resto. |
| 9 | Ayudar a reconocer, diagnosticar y recuperarse de errores | — | Mensajes en español que dicen qué pasó y qué hacer ("Actualice el mapa y elija de nuevo"), botón "Reintentar", y si alguien toma un asiento la app lo quita de la selección y recarga el mapa. |
| 10 | Ayuda y documentación | El mapa no explicaba cómo usarse. | Texto de ayuda breve sobre el mapa ("Toque los asientos que quiere (hasta 10)…"), textos auxiliares en los formularios ("Máximo $10000, hasta 2 decimales"). |

## Navegación (resumen)

- **Cliente:** Vuelos · Mis reservas (barra inferior). **Administrador:** Vuelos · Administración.
- Arriba, siempre: logo (→ inicio), flecha Volver (cuando hay a dónde volver) y el avatar de la cuenta
  (nombre, correo, rol, estado del servicio y cerrar sesión).
- El mapa de asientos no lleva barra inferior a propósito: es un paso a medio camino con su propio resumen y
  botón de confirmar; se sale con la flecha, el logo o las migas (y avisa si hay una selección sin guardar).

## Pendiente (ideas, no bloquea)
- Descargar el comprobante como archivo `.xml`/PDF.
- Recordar la sesión en varias pestañas y mostrar el tiempo restante del token.
