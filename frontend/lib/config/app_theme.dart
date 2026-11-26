import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Identidad visual "Ecuador" — Kuntur EC.
///
/// Los colores provienen de la bandera (azul, amarillo y rojo) con criterio de
/// contención operativa: el azul es el color de marca, el amarillo el acento de
/// alta atención y el rojo queda reservado a estados destructivos y errores.
/// Todas las combinaciones de texto sobre superficie/fondo superan WCAG AA (>= 4.5:1).
class AppColors {
  const AppColors._();

  // Bandera
  static const Color azul = Color(0xFF2A4365);
  static const Color azulHover = Color(0xFF233856);
  static const Color amarillo = Color(0xFFE9A820);
  static const Color rojo = Color(0xFFB5382C);

  // Andes y cielo
  static const Color azulNoche = Color(0xFF1C2B40);
  static const Color cielo = Color(0xFF5B7694);
  static const Color nieve = Color(0xFFFFFFFF);

  // Fondos y superficies cálidas (niebla de páramo)
  static const Color fondo = Color(0xFFF7F3EC);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieSutil = Color(0xFFFAF7F2);

  // Textos (contrastes verificados sobre #FFFFFF y #F7F3EC)
  static const Color textoPrincipal = Color(0xFF20262E); // > 13:1
  static const Color textoSecundario = Color(0xFF56606B); // 6.45:1 sobre blanco
  static const Color textoSuave = Color(0xFF656E77); // 5.19:1 sobre blanco

  // Bordes y divisores
  static const Color borde = Color(0xFFE3DBCD);
  static const Color divisor = Color(0xFFECE5D9);

  // Semánticos
  static const Color exito = Color(0xFF2A6F4F);
  static const Color exitoSuave = Color(0xFFE6F2EB);
  static const Color error = Color(0xFFB5382C);
  static const Color errorSuave = Color(0xFFF8E8E5);
  static const Color aviso = Color(0xFF8A5F00);
  static const Color avisoSuave = Color(0xFFFBF1D8);
  // Azul informativo oscurecido: 6.7:1 sobre infoSuave.
  static const Color info = Color(0xFF2E5278);
  static const Color infoSuave = Color(0xFFE8EDF3);
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient boton = LinearGradient(
    colors: [AppColors.azul, AppColors.azul],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Cielo del panel principal: de la noche andina al azul de la bandera.
  static const LinearGradient cielo = LinearGradient(
    colors: [AppColors.azulNoche, AppColors.azul],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient fondo = LinearGradient(
    colors: [Color(0xFFF1EADD), AppColors.fondo],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTextStyles {
  const AppTextStyles._();

  /// Numerales tabulares para evitar saltos horizontales en montos, horarios y contadores.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle titulo = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textoPrincipal,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const TextStyle subtitulo = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textoPrincipal,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle cuerpo = TextStyle(
    fontSize: 15,
    color: AppColors.textoSecundario,
    height: 1.5,
  );

  static const TextStyle nota = TextStyle(
    fontSize: 12.5,
    color: AppColors.textoSuave,
    height: 1.35,
  );

  /// Etiquetas de campo y encabezados discretos.
  static const TextStyle etiqueta = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textoSecundario,
    letterSpacing: 0.2,
  );

  static const TextStyle boton = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.15,
  );

  /// Cifras monetarias y totales con numerales tabulares.
  static const TextStyle moneda = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textoPrincipal,
    letterSpacing: -0.3,
    fontFeatures: tabular,
  );

  /// Códigos de vuelo, factura y datos numéricos alineados.
  static const TextStyle codigo = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.azul,
    letterSpacing: 0.3,
    fontFeatures: tabular,
  );
}

class AppDecorations {
  const AppDecorations._();

  /// Tarjeta estándar del sistema: radio limpio de 16 pt y borde definido sin doble elevación fantasma.
  static BoxDecoration tarjeta = BoxDecoration(
    color: AppColors.superficie,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.borde.withValues(alpha: 0.85)),
    boxShadow: [
      BoxShadow(
        color: AppColors.azulNoche.withValues(alpha: 0.045),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  /// Superficie sutil para paneles secundarios, resúmenes y bloques agrupados.
  static BoxDecoration panelSutil = BoxDecoration(
    color: AppColors.superficieSutil,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.borde.withValues(alpha: 0.7)),
  );
}

/// Transición de ruta que se anula cuando el sistema pide "Reducir movimiento".
class _TransicionQueRespetaElMovimiento extends PageTransitionsBuilder {
  const _TransicionQueRespetaElMovimiento(this.base);

  final PageTransitionsBuilder base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return base.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}

class AppTheme {
  const AppTheme._();

  /// Tema claro andino de Kuntur EC.
  static final ThemeData light = _build();

  static ThemeData _build() {
    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.fondo,
      focusColor: AppColors.azul.withValues(alpha: 0.14),
      hoverColor: AppColors.azul.withValues(alpha: 0.05),
      splashColor: AppColors.azul.withValues(alpha: 0.08),
      colorScheme: const ColorScheme.light(
        primary: AppColors.azul,
        onPrimary: Colors.white,
        secondary: AppColors.cielo,
        onSecondary: Colors.white,
        tertiary: AppColors.amarillo,
        onTertiary: AppColors.azulNoche,
        surface: AppColors.superficie,
        onSurface: AppColors.textoPrincipal,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.borde,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.azul,
        selectionColor: AppColors.amarillo.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.azul,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.azulNoche,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: borde(AppColors.borde),
        enabledBorder: borde(AppColors.borde),
        focusedBorder: borde(AppColors.azul, 2),
        errorBorder: borde(AppColors.error),
        focusedErrorBorder: borde(AppColors.error, 2),
        labelStyle: const TextStyle(color: AppColors.textoSuave),
        floatingLabelStyle: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.textoSuave),
        errorMaxLines: 3,
        helperMaxLines: 2,
        errorStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
        prefixIconColor: AppColors.textoSuave,
        suffixIconColor: AppColors.textoSuave,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          side: const BorderSide(color: AppColors.azul, width: 1.4),
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azul,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.selected) ? AppColors.azul : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.selected) ? Colors.white : AppColors.textoPrincipal,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: AppColors.amarillo.withValues(alpha: 0.45),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12.5,
            fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: estados.contains(WidgetState.selected) ? AppColors.textoPrincipal : AppColors.textoSecundario,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected) ? AppColors.azulNoche : AppColors.textoSecundario,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _TransicionQueRespetaElMovimiento(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.iOS: _TransicionQueRespetaElMovimiento(CupertinoPageTransitionsBuilder()),
          TargetPlatform.macOS: _TransicionQueRespetaElMovimiento(CupertinoPageTransitionsBuilder()),
          TargetPlatform.windows: _TransicionQueRespetaElMovimiento(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.linux: _TransicionQueRespetaElMovimiento(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.fuchsia: _TransicionQueRespetaElMovimiento(FadeForwardsPageTransitionsBuilder()),
        },
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.borde,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.subtitulo.copyWith(fontSize: 19),
        contentTextStyle: AppTextStyles.cuerpo,
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.azulNoche,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divisor, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.azul),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.infoSuave,
        labelStyle: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
