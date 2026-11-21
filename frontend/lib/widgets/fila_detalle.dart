import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Una fila "Etiqueta … valor" para bloques de datos (detalle de vuelo,
/// reserva, comprobante y panel de administración).
///
/// Reemplaza a `_Dato`, `_Fila` y `_Linea`, que repetían la misma estructura con
/// pequeñas variaciones en tres pantallas.
class FilaDetalle extends StatelessWidget {
  const FilaDetalle({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.icono,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;

  /// Icono opcional a la izquierda de la etiqueta.
  final IconData? icono;

  /// El valor va un punto más grande y en negrita (totales, estado principal).
  final bool destacado;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$etiqueta: $valor',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: AppColors.textoSuave),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(etiqueta, style: AppTextStyles.cuerpo)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  valor,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: destacado ? 16 : 15,
                    fontWeight: destacado ? FontWeight.w800 : FontWeight.w700,
                    color: AppColors.textoPrincipal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
