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
  static const Color azul = Color(0xFF2A4365);
  static const Color amarillo = Color(0xFFE9A820);
  static const Color rojo = Color(0xFFB5382C);

  // Andes y cielo
  static const Color azulNoche = Color(0xFF1C2B40);
  static const Color cielo = Color(0xFF5B7694);
  static const Color nieve = Color(0xFFFFFFFF);

  // Fondos y superficies
  static const Color fondo = Color(0xFFF7F3EC);
  static const Color superficie = Color(0xFFFFFFFF);

  // Textos
  static const Color textoPrincipal = Color(0xFF20262E);
  static const Color textoSecundario = Color(0xFF56606B);
  static const Color textoSuave = Color(0xFF656E77);

  // Bordes
  static const Color borde = Color(0xFFE3DBCD);
  static const Color divisor = Color(0xFFECE5D9);

  // Semánticos
  static const Color exito = Color(0xFF2A6F4F);
  static const Color exitoSuave = Color(0xFFE6F2EB);
  static const Color error = Color(0xFFB5382C);
  static const Color errorSuave = Color(0xFFF8E8E5);
  static const Color aviso = Color(0xFF8A5F00);
  static const Color avisoSuave = Color(0xFFFBF1D8);
  static const Color info = Color(0xFF4F6D8F);
  static const Color infoSuave = Color(0xFFE8EDF3);
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient boton = LinearGradient(
    // Plano a propósito: un solo color, sin brillo de degradado.
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
        color: Colors.black.withValues(alpha: 0.06),
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
        errorMaxLines: 3, // los mensajes largos se ven completos en pantallas angostas
        helperMaxLines: 2,
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
        indicatorColor: AppColors.amarillo.withValues(alpha: 0.55),
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
