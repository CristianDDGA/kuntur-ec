import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Botón principal con el degradado de marca. Muestra un indicador de carga y
/// se desactiva mientras `cargando` o si `onPressed` es nulo.
class BotonDegradado extends StatelessWidget {
  const BotonDegradado({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null && !cargando;
    return Semantics(
      button: true,
      enabled: habilitado,
      label: cargando ? '$texto, cargando' : texto,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: habilitado || cargando ? AppGradients.boton : null,
            color: habilitado || cargando ? null : AppColors.borde,
            borderRadius: BorderRadius.circular(14),
            boxShadow: habilitado
                ? [
                    BoxShadow(
                      color: AppColors.azul.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: habilitado ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: cargando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(texto, style: AppTextStyles.boton),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
