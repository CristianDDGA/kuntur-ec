import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Motores de **morfismo líquido** de Kuntur EC.
///
/// Ondas Bézier reactivas, selectores con pastilla elástica y cápsulas que
/// cambian de geometría. Todo con animaciones finitas y respeto a Reduce Motion.

/// Fondo orgánico con dos ondas Bézier que se desplazan según [fase] (0 a 1).
///
/// Se usa detrás del panel de acceso y de las cabeceras de sección: la onda se
/// mueve al cambiar el foco del formulario, sin distraer de la lectura.
class FondoLiquidMorph extends StatelessWidget {
  const FondoLiquidMorph({super.key, this.fase = 0, this.color = AppColors.infoSuave, this.child});

  final double fase;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fase.clamp(0.0, 1.0)),
        duration: AppMotion.heroeDe(context),
        curve: AppMotion.curvaLiquida,
        builder: (context, valor, hijo) => CustomPaint(
          painter: _PintorOndas(fase: valor, color: color),
          child: hijo,
        ),
        child: child,
      );
}

/// Opción de un [SelectorLiquidMorph].
class OpcionLiquid<T> {
  const OpcionLiquid({required this.valor, required this.etiqueta, this.icono});

  final T valor;
  final String etiqueta;
  final IconData? icono;
}

/// Selector segmentado con indicador de pastilla líquida que se desliza y se
/// asienta con curva elástica suave entre los segmentos.
///
/// Mantiene los textos visibles (`find.text('Factura XML')` sigue funcionando) y
/// altura táctil de 48 pt.
class SelectorLiquidMorph<T> extends StatelessWidget {
  const SelectorLiquidMorph({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onCambio,
    this.alto = 48,
  }) : assert(opciones.length >= 2, 'El selector necesita al menos dos opciones.');

  final List<OpcionLiquid<T>> opciones;
  final T seleccion;
  final ValueChanged<T> onCambio;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final indice = opciones.indexWhere((o) => o.valor == seleccion).clamp(0, opciones.length - 1);
    return SizedBox(
      height: alto,
      child: LayoutBuilder(
        builder: (context, caja) {
          final ancho = caja.maxWidth / opciones.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.infoSuave,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: AppMotion.mediaDe(context),
                curve: AppMotion.curvaLiquida,
                left: indice * ancho + 3,
                top: 3,
                bottom: 3,
                width: ancho - 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.azul,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azul.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, opcion) in opciones.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == indice,
                        label: opcion.etiqueta,
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: i == indice ? null : () => onCambio(opcion.valor),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (opcion.icono != null) ...[
                                      Icon(
                                        opcion.icono,
                                        size: 17,
                                        color: i == indice ? Colors.white : AppColors.textoSecundario,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      opcion.etiqueta,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: i == indice ? FontWeight.w800 : FontWeight.w600,
                                        color: i == indice ? Colors.white : AppColors.textoPrincipal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cápsula que cambia de geometría y color al activarse (respuesta líquida).
class CapsulaLiquidMorph extends StatelessWidget {
  const CapsulaLiquidMorph({
    super.key,
    required this.child,
    this.activa = false,
    this.radio = 16,
    this.color,
    this.colorActiva,
    this.padding,
  });

  final Widget child;
  final bool activa;
  final double radio;
  final Color? color;
  final Color? colorActiva;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: AppMotion.rapidaDe(context),
        curve: AppMotion.curvaLiquida,
        padding: padding,
        decoration: BoxDecoration(
          color: activa
              ? (colorActiva ?? AppColors.azul.withValues(alpha: 0.08))
              : (color ?? Colors.transparent),
          borderRadius: BorderRadius.circular(activa ? radio * 1.35 : radio),
        ),
        child: child,
      );
}

/// Contenedor que se expande/colapsa con geometría fluida (buscador, filtros).
class ContenedorLiquidMorph extends StatelessWidget {
  const ContenedorLiquidMorph({
    super.key,
    required this.child,
    this.expandido = true,
    this.radio = 20,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final bool expandido;
  final double radio;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: AnimatedSize(
          duration: AppMotion.mediaDe(context),
          curve: AppMotion.curvaLiquida,
          alignment: alignment,
          child: expandido ? child : const SizedBox(width: double.infinity),
        ),
      );
}

/// Barra de progreso con relleno fluido (requisitos de contraseña, ocupación).
class BarraLiquidMorph extends StatelessWidget {
  const BarraLiquidMorph({
    super.key,
    required this.valor,
    this.alto = 8,
    this.color = AppColors.azul,
    this.fondo = AppColors.divisor,
  });

  /// Progreso de 0 a 1.
  final double valor;
  final double alto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: valor.clamp(0.0, 1.0)),
        duration: AppMotion.mediaDe(context),
        curve: AppMotion.curvaLiquida,
        builder: (context, avance, _) => ClipRRect(
          borderRadius: BorderRadius.circular(alto),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: alto,
            backgroundColor: fondo,
            valueColor: AlwaysStoppedAnimation<Color>(avance >= 1 ? AppColors.exito : color),
          ),
        ),
      );
}

class _PintorOndas extends CustomPainter {
  _PintorOndas({required this.fase, required this.color});

  final double fase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Onda principal (tono suave del tema).
    final desplazamiento = math.sin(fase * math.pi * 2);
    final ola = Path()
      ..moveTo(0, h * (0.62 + 0.06 * desplazamiento))
      ..cubicTo(
        w * 0.25,
        h * (0.40 + 0.08 * desplazamiento),
        w * 0.55,
        h * (0.78 - 0.08 * desplazamiento),
        w,
        h * (0.52 - 0.04 * desplazamiento),
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ola, Paint()..color = color.withValues(alpha: 0.85));

    // Segunda onda, más tenue y contrafase.
    final ola2 = Path()
      ..moveTo(0, h * (0.78 - 0.05 * desplazamiento))
      ..cubicTo(
        w * 0.30,
        h * (0.92 + 0.05 * desplazamiento),
        w * 0.60,
        h * (0.62 - 0.06 * desplazamiento),
        w,
        h * (0.84 + 0.03 * desplazamiento),
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ola2, Paint()..color = AppColors.azul.withValues(alpha: 0.06));

    // Detalle dorado: única veta de marca.
    final veta = Path()
      ..moveTo(w * 0.55, h * (0.70 + 0.03 * desplazamiento))
      ..quadraticBezierTo(w * 0.75, h * 0.46, w, h * (0.58 + 0.02 * desplazamiento))
      ..lineTo(w, h * 0.68)
      ..quadraticBezierTo(w * 0.78, h * 0.58, w * 0.55, h * (0.80 + 0.03 * desplazamiento))
      ..close();
    canvas.drawPath(veta, Paint()..color = AppColors.amarillo.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(_PintorOndas oldDelegate) =>
      oldDelegate.fase != fase || oldDelegate.color != color;
}
