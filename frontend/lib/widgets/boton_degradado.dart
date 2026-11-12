import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Botón principal de la marca (color plano). Muestra un indicador de carga y se desactiva
/// mientras `cargando` o si `onPressed` es nulo.
///
/// (El nombre viene de cuando llevaba degradado; ahora es plano a propósito.)
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
        // Mientras carga se ve igual que activo (con el indicador); desactivado se ve gris.
        color: habilitado || cargando ? AppColors.azul : AppColors.borde,
        elevation: habilitado ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
                  // Desactivado: texto oscuro sobre gris (el blanco sobre gris claro no se leía).
                  : Text(texto, style: AppTextStyles.boton.copyWith(color: habilitado ? Colors.white : AppColors.textoSecundario)),
            ),
          ),
        ),
      ),
    );
  }
}
