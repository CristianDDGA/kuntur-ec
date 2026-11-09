import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF1565C0);

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}
