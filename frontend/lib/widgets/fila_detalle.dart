import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Una fila "Etiqueta … valor" para bloques de datos (detalle de vuelo,
/// reserva, comprobante y panel de administración) con numerales tabulares y
/// adaptación vertical cuando la escala tipográfica supera el 135 %.
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

  bool get _esCifraCorta => valor.length <= 16 && !valor.contains('@');

  @override
  Widget build(BuildContext context) {
    final textoGrande = MediaQuery.textScalerOf(context).scale(15) > 20;
    final estiloValor = TextStyle(
      fontSize: destacado ? 16 : 15,
      fontWeight: destacado ? FontWeight.w800 : FontWeight.w700,
      color: AppColors.textoPrincipal,
      fontFeatures: AppTextStyles.tabular,
    );

    return Semantics(
      label: '$etiqueta: $valor',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: textoGrande
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icono != null) ...[
                        Icon(icono, size: 18, color: AppColors.textoSuave),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(etiqueta, style: AppTextStyles.cuerpo)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(valor, style: estiloValor),
                ],
              )
            : Row(
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
                      softWrap: !_esCifraCorta,
                      style: estiloValor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
