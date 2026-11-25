import 'package:flutter/material.dart';

/// Tokens de movimiento físico de Kuntur EC.
///
/// Basado en las curvas y presupuestos de ingeniería de diseño:
/// - Las animaciones de UI operativas permanecen por debajo de 300 ms.
/// - Las interacciones táctiles usan timing asimétrico (`100 ms` al presionar,
///   `160 ms` al soltar) y una curva `ease-out` fuerte (`Cubic(0.23, 1, 0.32, 1)`).
/// - Bajo "Reducir movimiento" (`MediaQuery.disableAnimationsOf`), los desplazamientos
///   y escalas devuelven `Duration.zero`, mientras [opacidadDe] mantiene un fundido
///   suave de `120 ms` para no perder la legibilidad del cambio de estado.
class AppMotion {
  const AppMotion._();

  /// Compresión táctil al presionar un control (`100 ms`, respuesta instantánea).
  static const Duration presionEntrada = Duration(milliseconds: 100);

  /// Recuperación al soltar un control (`160 ms`, asentamiento limpio).
  static const Duration presionSalida = Duration(milliseconds: 160);

  /// Cambios de estado inmediatos: checkmarks, selección de asiento, chips.
  static const Duration rapida = Duration(milliseconds: 160);

  /// Transiciones de contenido y selectores segmentados (`<= 250 ms`).
  static const Duration media = Duration(milliseconds: 220);

  /// Expansiones de contenedor o revelados más amplios (`<= 300 ms`).
  static const Duration lenta = Duration(milliseconds: 280);

  /// Modales, hojas y entradas de marca (excepción documentada `<= 360 ms`).
  static const Duration heroe = Duration(milliseconds: 320);

  /// Fundido suave preservado incluso bajo Reducir Movimiento para legibilidad de estado.
  static const Duration opacidadReducida = Duration(milliseconds: 120);

  /// Strong ease-out (`cubic-bezier(0.23, 1, 0.32, 1)`): arranca con respuesta inmediata.
  static const Curve curvaSalidaFuerte = Cubic(0.23, 1, 0.32, 1);

  /// Alias de entrada: usa siempre strong ease-out (nunca ease-in en UI).
  static const Curve curvaEntrada = curvaSalidaFuerte;

  /// Respuesta táctil inmediata en botones, tarjetas y asientos.
  static const Curve curvaTactil = curvaSalidaFuerte;

  /// Strong ease-in-out (`cubic-bezier(0.77, 0, 0.175, 1)`) para elementos que se mueven en pantalla.
  static const Curve curvaLiquida = Cubic(0.77, 0, 0.175, 1);

  /// Curva tipo hoja/drawer (`cubic-bezier(0.32, 0.72, 0, 1)`).
  static const Curve curvaHoja = Cubic(0.32, 0.72, 0, 1);

  /// Indica si el sistema solicita reducir movimiento.
  static bool movimientoReducido(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// Duración efectiva para transformaciones espaciales (0 bajo Reducir Movimiento).
  static Duration duracion(BuildContext context, Duration base) =>
      movimientoReducido(context) ? Duration.zero : base;

  /// Duración efectiva para transiciones de opacidad/color (gentil bajo Reducir Movimiento).
  static Duration opacidadDe(BuildContext context, [Duration base = rapida]) =>
      movimientoReducido(context) ? opacidadReducida : base;

  static Duration presionDe(BuildContext context, {required bool presionado}) =>
      duracion(context, presionado ? presionEntrada : presionSalida);

  static Duration rapidaDe(BuildContext context) => duracion(context, rapida);

  static Duration mediaDe(BuildContext context) => duracion(context, media);

  static Duration lentaDe(BuildContext context) => duracion(context, lenta);

  static Duration heroeDe(BuildContext context) => duracion(context, heroe);
}
