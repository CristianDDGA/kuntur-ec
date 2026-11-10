import 'package:flutter/material.dart';

/// Identidad visual "Ecuador".
///
/// Los colores salen de la bandera (azul, amarillo y rojo) usados con criterio:
/// el azul es el color de marca, el amarillo es el acento y el rojo queda para
/// errores y detalles. Los tonos fríos y los fondos "niebla de páramo" vienen de
/// los Andes. (APE8 usa tonos tierra; esta app parte de su estructura pero con
/// otra paleta y otro carácter.)
class AppColors {
  const AppColors._();

  // Bandera
  static const Color azul = Color(0xFF0B4DA2);
  static const Color amarillo = Color(0xFFFFC800);
  static const Color rojo = Color(0xFFD62839);

  // Andes y cielo
  static const Color azulNoche = Color(0xFF071E45);
  static const Color cielo = Color(0xFF2F7DD8);
  static const Color nieve = Color(0xFFFFFFFF);

  // Fondos y superficies
  static const Color fondo = Color(0xFFF2F6FC);
  static const Color superficie = Color(0xFFFFFFFF);

  // Textos
  static const Color textoPrincipal = Color(0xFF0A2540);
  static const Color textoSecundario = Color(0xFF4A5F7D);
  static const Color textoSuave = Color(0xFF7A8BA3);

  // Bordes
  static const Color borde = Color(0xFFD0DBEA);
  static const Color divisor = Color(0xFFE1E9F4);

  // Semánticos
  static const Color exito = Color(0xFF1B8A5A);
  static const Color exitoSuave = Color(0xFFE5F5EC);
  static const Color error = Color(0xFFC8283A);
  static const Color errorSuave = Color(0xFFFDEBED);
  static const Color aviso = Color(0xFFB57F00);
  static const Color avisoSuave = Color(0xFFFFF6D6);
  static const Color info = Color(0xFF2F7DD8);
  static const Color infoSuave = Color(0xFFE6F0FC);
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient boton = LinearGradient(
    colors: [AppColors.azul, AppColors.cielo],
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
    colors: [Color(0xFFE6EEF9), AppColors.fondo],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle titulo = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textoPrincipal,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const TextStyle subtitulo = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textoPrincipal,
  );

  static const TextStyle cuerpo = TextStyle(
    fontSize: 14,
    color: AppColors.textoSecundario,
    height: 1.45,
  );

  static const TextStyle nota = TextStyle(fontSize: 12, color: AppColors.textoSuave);

  static const TextStyle boton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.4,
  );
}

class AppDecorations {
  const AppDecorations._();

  static BoxDecoration tarjeta = BoxDecoration(
    color: AppColors.superficie,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.borde.withValues(alpha: 0.6)),
    boxShadow: [
      BoxShadow(
        color: AppColors.azul.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class AppTheme {
  const AppTheme._();

  /// La app usa un solo tema claro (los colores de marca no se invierten).
  static final ThemeData light = _build();

  static ThemeData _build() {
    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.fondo,
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
        errorStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
        prefixIconColor: AppColors.textoSuave,
        suffixIconColor: AppColors.textoSuave,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          side: const BorderSide(color: AppColors.azul, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azul,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
