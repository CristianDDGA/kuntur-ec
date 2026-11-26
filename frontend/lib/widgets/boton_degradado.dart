import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Jerarquía semántica del botón: primario (acción principal), secundario
/// (alternativa con borde) o destructivo (eliminar/cancelar algo).
enum VarianteBoton { primario, secundario, destructivo }

/// Botón principal de Kuntur EC con respuesta táctil GPU (`AnimatedScale` 0.97)
/// asimétrica (`100 ms` al presionar / `160 ms` al soltar), foco de teclado visible
/// y estado de carga inline sin saltos de layout.
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
  bool _enfocado = false;

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
    final colorSpinner = widget.variante == VarianteBoton.secundario ? AppColors.azul : Colors.white;

    return Semantics(
      button: true,
      enabled: habilitado,
      label: widget.cargando ? '${widget.texto}, cargando' : widget.texto,
      onTap: habilitado ? widget.onPressed : null,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado && habilitado ? 0.97 : 1,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: habilitado && widget.variante != VarianteBoton.secundario
                ? [
                    BoxShadow(
                      color: colorFondo.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: colorFondo,
            elevation: 0,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: habilitado ? widget.onPressed : null,
              onHighlightChanged: (valor) {
                if (_presionado != valor) setState(() => _presionado = valor);
              },
              onFocusChange: (valor) {
                if (_enfocado != valor) setState(() => _enfocado = valor);
              },
              hoverColor: widget.variante == VarianteBoton.secundario
                  ? AppColors.azul.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              focusColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _enfocado
                      ? Border.all(
                          color: widget.variante == VarianteBoton.secundario ? AppColors.azul : AppColors.amarillo,
                          width: 2.2,
                        )
                      : borde != null
                          ? Border.all(color: habilitado ? borde : AppColors.borde, width: 1.4)
                          : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppMotion.opacidadDe(context),
                      switchInCurve: AppMotion.curvaSalidaFuerte,
                      child: widget.cargando
                          ? SizedBox(
                              key: const ValueKey('cargando'),
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(colorSpinner),
                              ),
                            )
                          : Text(
                              widget.texto,
                              key: const ValueKey('texto'),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.boton.copyWith(color: colorContenido),
                            ),
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
