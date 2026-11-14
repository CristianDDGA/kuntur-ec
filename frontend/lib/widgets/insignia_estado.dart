import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Familias semánticas de una insignia: el color siempre dice lo mismo.
enum TipoInsignia { exito, aviso, error, info, neutro }

/// Píldora de estado ("Agotado", "Quedan 3", "Programada", ...).
///
/// Única implementación de badge/píldora de la app: el color y el texto viven
/// juntos, así una misma situación nunca se pinta de dos formas distintas.
class InsigniaEstado extends StatelessWidget {
  const InsigniaEstado({super.key, required this.texto, this.tipo = TipoInsignia.info});

  final String texto;
  final TipoInsignia tipo;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color fondo) = switch (tipo) {
      TipoInsignia.exito => (AppColors.exito, AppColors.exitoSuave),
      TipoInsignia.aviso => (AppColors.aviso, AppColors.avisoSuave),
      TipoInsignia.error => (AppColors.error, AppColors.errorSuave),
      TipoInsignia.info => (AppColors.azul, AppColors.infoSuave),
      TipoInsignia.neutro => (AppColors.textoSecundario, AppColors.divisor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
