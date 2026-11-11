import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/vuelo.dart';

/// Disponibilidad del vuelo: "Agotado", "Quedan 3" o "42 asientos".
class EtiquetaAsientos extends StatelessWidget {
  const EtiquetaAsientos({super.key, required this.vuelo});

  final Vuelo vuelo;

  @override
  Widget build(BuildContext context) {
    final (texto, color, fondo) = vuelo.agotado
        ? ('Agotado', AppColors.error, AppColors.errorSuave)
        : vuelo.pocosAsientos
            ? ('Quedan ${vuelo.asientosDisponibles}', AppColors.aviso, AppColors.avisoSuave)
            : ('${vuelo.asientosDisponibles} asientos', AppColors.exito, AppColors.exitoSuave);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}
