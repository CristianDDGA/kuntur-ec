import 'package:flutter/material.dart';

/// Tokens de movimiento de Kuntur EC.
///
/// Un único lugar para duraciones y curvas: así todas las animaciones se sienten
/// parte de la misma app. Los helpers [rapidaDe], [mediaDe] y [lentaDe] respetan
/// la preferencia del sistema "Reducir movimiento" devolviendo `Duration.zero`
/// (Apple HIG, `motion.md`: la animación nunca es el único portador de
/// significado y siempre tiene una respuesta para Reduce Motion).
class AppMotion {
  const AppMotion._();

  /// Cambios de estado inmediatos: checkmarks, selección de asiento, chips.
  static const Duration rapida = Duration(milliseconds: 180);

  /// Entradas y transiciones de contenido: skeleton, cambio de total, hojas.
  static const Duration media = Duration(milliseconds: 260);

  /// Cambios de pantalla o revelados amplios (expansión del buscador).
  static const Duration lenta = Duration(milliseconds: 420);

  /// Entrada de ilustraciones y héroes visuales (isométrico, liquid morph).
  static const Duration heroe = Duration(milliseconds: 520);

  /// Curva de entrada: arranca rápido y frena suave (nada de rebotes bruscos).
  static const Curve curvaEntrada = Curves.easeOutCubic;

  /// Curva para respuesta táctil (presionar/soltar).
  static const Curve curvaTactil = Curves.easeInOut;

  /// Curva orgánica para el morfismo líquido y los asentamientos elásticos.
  static const Curve curvaLiquida = Curves.easeInOutCubic;

  /// Duración efectiva según la preferencia de accesibilidad del sistema.
  static Duration duracion(BuildContext context, Duration base) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;

  static Duration rapidaDe(BuildContext context) => duracion(context, rapida);

  static Duration mediaDe(BuildContext context) => duracion(context, media);

  static Duration lentaDe(BuildContext context) => duracion(context, lenta);

  static Duration heroeDe(BuildContext context) => duracion(context, heroe);
}
