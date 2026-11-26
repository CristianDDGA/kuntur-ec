import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Control de paginación: «‹ Anterior  Página 2 de 5  Siguiente ›».
/// Usa numerales tabulares para que los botones no salten al pasar de 9 a 10
/// y anuncia el cambio de página como `liveRegion`.
class ControlPaginas extends StatelessWidget {
  const ControlPaginas({
    super.key,
    required this.pagina,
    required this.totalPaginas,
    required this.onCambiar,
    this.ocupado = false,
  });

  final int pagina;
  final int totalPaginas;
  final ValueChanged<int> onCambiar;

  /// Mientras llega la página nueva se bloquean los botones (evita pedir dos a la vez).
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1) return const SizedBox.shrink();
    final anterior = pagina > 1 && !ocupado;
    final siguiente = pagina < totalPaginas && !ocupado;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: IconButton.outlined(
              tooltip: 'Página anterior',
              onPressed: anterior ? () => onCambiar(pagina - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Semantics(
                liveRegion: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Página $pagina de $totalPaginas',
                    style: AppTextStyles.subtitulo.copyWith(
                      fontSize: 15,
                      fontFeatures: AppTextStyles.tabular,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: IconButton.outlined(
              tooltip: 'Página siguiente',
              onPressed: siguiente ? () => onCambiar(pagina + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}
