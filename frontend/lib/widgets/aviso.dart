import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum TipoAviso { error, exito, info }

/// Mensaje dentro del formulario (por ejemplo, el error devuelto por la API).
class AvisoInline extends StatelessWidget {
  const AvisoInline({super.key, required this.texto, this.tipo = TipoAviso.error});

  final String texto;
  final TipoAviso tipo;

  @override
  Widget build(BuildContext context) {
    final (color, fondo, icono) = switch (tipo) {
      TipoAviso.error => (AppColors.error, AppColors.errorSuave, Icons.error_outline),
      TipoAviso.exito => (AppColors.exito, AppColors.exitoSuave, Icons.check_circle_outline),
      TipoAviso.info => (AppColors.info, AppColors.infoSuave, Icons.info_outline),
    };
    return Semantics(
      liveRegion: true, // los lectores de pantalla anuncian el error al aparecer
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso breve flotante (SnackBar) con el estilo de la app.
void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
