import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Jerarquía semántica del botón: primario (acción principal), secundario
/// (alternativa con borde) o destructivo (eliminar/cancelar algo).
enum VarianteBoton { primario, secundario, destructivo }

/// Botón principal de la marca (color plano). Muestra un indicador de carga,
/// se desactiva mientras `cargando` o si `onPressed` es nulo y responde con una
/// compresión sutil al presionar (`AnimatedScale` 0.98).
///
/// (El nombre viene de cuando llevaba degradado; ahora es plano a propósito.)
class BotonDegradado extends StatefulWidget {
  const BotonDegradado({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.variante = VarianteBoton.primario,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final VarianteBoton variante;

  @override
  State<BotonDegradado> createState() => _BotonDegradadoState();
}

class _BotonDegradadoState extends State<BotonDegradado> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.onPressed != null && !widget.cargando;
    final (Color fondo, Color colorTexto, Color? borde) = switch (widget.variante) {
      VarianteBoton.primario => (AppColors.azul, Colors.white, null),
      VarianteBoton.secundario => (AppColors.superficie, AppColors.azul, AppColors.azul),
      VarianteBoton.destructivo => (AppColors.error, Colors.white, null),
    };
    final colorFondo = habilitado || widget.cargando ? fondo : AppColors.borde;
    final colorContenido = habilitado || widget.cargando ? colorTexto : AppColors.textoSecundario;

    return Semantics(
      button: true,
      enabled: habilitado,
      label: widget.cargando ? '${widget.texto}, cargando' : widget.texto,
      // excludeSemantics oculta el InkWell interno; la acción se declara aquí para
      // que VoiceOver/TalkBack puedan activar el botón.
      onTap: habilitado ? widget.onPressed : null,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado && habilitado ? 0.98 : 1,
        duration: AppMotion.rapidaDe(context),
        curve: AppMotion.curvaTactil,
        child: Material(
          // Mientras carga se ve igual que activo (con el indicador); desactivado se ve gris.
          color: colorFondo,
          elevation: habilitado ? 2 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: habilitado ? widget.onPressed : null,
            onHighlightChanged: (valor) => setState(() => _presionado = valor),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: borde == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: habilitado ? borde : AppColors.borde, width: 1.5),
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: AppMotion.rapidaDe(context),
                    child: widget.cargando
                        ? const SizedBox(
                            key: ValueKey('cargando'),
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        // Desactivado: texto oscuro sobre gris (el blanco sobre gris claro no se leía).
                        : Text(
                            widget.texto,
                            key: const ValueKey('texto'),
                            style: AppTextStyles.boton.copyWith(color: colorContenido),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
