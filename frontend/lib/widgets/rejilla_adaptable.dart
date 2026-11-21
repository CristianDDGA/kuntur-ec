import 'package:flutter/material.dart';

/// Lista de tarjetas que se adapta al ancho: 1 columna en celular, 2 en pantallas anchas
/// (web/escritorio). Es una página web adaptable, no una app móvil.
class RejillaAdaptable extends StatelessWidget {
  const RejillaAdaptable({super.key, required this.hijos, this.anchoMinimoColumna = 480, this.espacio = 12});

  final List<Widget> hijos;

  /// Ancho mínimo deseado por columna; si cabe más de una, se reparten en columnas iguales.
  final double anchoMinimoColumna;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final columnas = ((caja.maxWidth + espacio) / (anchoMinimoColumna + espacio)).floor().clamp(1, 4);
        if (columnas == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final h in hijos) Padding(padding: EdgeInsets.only(bottom: espacio), child: h),
            ],
          );
        }
        final ancho = (caja.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
        );
      },
    );
  }
}
