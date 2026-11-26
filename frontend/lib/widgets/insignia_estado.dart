import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Familias semánticas de una insignia: el color siempre comunica el mismo significado.
enum TipoInsignia { exito, aviso, error, info, neutro }

/// Píldora de estado ("Agotado", "Quedan 3", "Programada", ...) en una sola línea
/// con figuras tabulares para evitar saltos de ancho en contadores.
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
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFeatures: AppTextStyles.tabular,
        ),
      ),
    );
  }
}
