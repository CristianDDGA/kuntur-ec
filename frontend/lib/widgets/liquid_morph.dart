import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Motores de **morfismo líquido** de Kuntur EC.
///
/// Optimizados para GPU y accesibilidad:
/// - [FondoLiquidMorph] se aísla en `RepaintBoundary` sin repintar por foco de teclado.
/// - [SelectorLiquidMorph] expone acciones semánticas completas (`Semantics.onTap`),
///   soporta navegación por teclado y desliza su pastilla con `AnimatedAlign` + `FractionallySizedBox`.

/// Fondo orgánico estático con ondas Bézier suaves detrás de paneles de autenticación.
class FondoLiquidMorph extends StatelessWidget {
  const FondoLiquidMorph({super.key, this.fase = 0, this.color = AppColors.infoSuave, this.child});

  final double fase;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _PintorOndas(fase: fase.clamp(0.0, 1.0), color: color),
          child: child,
        ),
      );
}

/// Opción de un [SelectorLiquidMorph].
class OpcionLiquid<T> {
  const OpcionLiquid({required this.valor, required this.etiqueta, this.icono});

  final T valor;
  final String etiqueta;
  final IconData? icono;
}

/// Selector segmentado con indicador deslizante suave (`200 ms`, `curvaSalidaFuerte`).
///
/// Cumple WCAG AA y Playwright/VoiceOver: cada segmento declara `Semantics(button, selected, onTap)`,
/// permanece alcanzable mediante teclado y adapta su altura mínima al `textScaler` del sistema.
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
    final alignmentX = opciones.length <= 1 ? 0.0 : -1.0 + (2.0 * indice) / (opciones.length - 1);
    final altoEscalado = MediaQuery.textScalerOf(context).scale(14) > 18 ? alto + 8 : alto;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: altoEscalado),
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.infoSuave,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borde.withValues(alpha: 0.7)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: AppMotion.mediaDe(context),
                  curve: AppMotion.curvaSalidaFuerte,
                  alignment: Alignment(alignmentX, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / opciones.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.azul,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.azul.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
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
                        onTap: () {
                          if (i != indice) onCambio(opcion.valor);
                        },
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () {
                              if (i != indice) onCambio(opcion.valor);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Center(
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
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cápsula que cambia de tono suavemente al activarse.
class CapsulaLiquidMorph extends StatelessWidget {
  const CapsulaLiquidMorph({
    super.key,
    required this.child,
    this.activa = false,
    this.radio = 14,
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
        duration: AppMotion.opacidadDe(context),
        curve: AppMotion.curvaSalidaFuerte,
        padding: padding,
        decoration: BoxDecoration(
          color: activa
              ? (colorActiva ?? AppColors.azul.withValues(alpha: 0.08))
              : (color ?? Colors.transparent),
          borderRadius: BorderRadius.circular(radio),
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
    this.radio = 16,
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
          curve: AppMotion.curvaSalidaFuerte,
          alignment: alignment,
          child: expandido ? child : const SizedBox(width: double.infinity),
        ),
      );
}

/// Barra de progreso con relleno fluido (requisitos de contraseña, ocupación).
/// Solo anima cuando cambia el valor, sin reiniciar desde 0 al montar.
class BarraLiquidMorph extends StatelessWidget {
  const BarraLiquidMorph({
    super.key,
    required this.valor,
    this.alto = 6,
    this.color = AppColors.azul,
    this.fondo = AppColors.divisor,
  });

  /// Progreso de 0 a 1.
  final double valor;
  final double alto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    final objetivo = valor.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: objetivo),
      duration: AppMotion.rapidaDe(context),
      curve: AppMotion.curvaSalidaFuerte,
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
}

class _PintorOndas extends CustomPainter {
  _PintorOndas({required this.fase, required this.color});

  final double fase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final desplazamiento = math.sin(fase * math.pi * 2);
    final ola = Path()
      ..moveTo(0, h * (0.64 + 0.04 * desplazamiento))
      ..cubicTo(
        w * 0.25,
        h * (0.44 + 0.06 * desplazamiento),
        w * 0.55,
        h * (0.78 - 0.06 * desplazamiento),
        w,
        h * (0.54 - 0.03 * desplazamiento),
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ola, Paint()..color = color.withValues(alpha: 0.8));

    final ola2 = Path()
      ..moveTo(0, h * (0.80 - 0.04 * desplazamiento))
      ..cubicTo(
        w * 0.30,
        h * (0.92 + 0.04 * desplazamiento),
        w * 0.60,
        h * (0.64 - 0.04 * desplazamiento),
        w,
        h * (0.84 + 0.02 * desplazamiento),
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ola2, Paint()..color = AppColors.azul.withValues(alpha: 0.05));

    final veta = Path()
      ..moveTo(w * 0.55, h * (0.72 + 0.02 * desplazamiento))
      ..quadraticBezierTo(w * 0.75, h * 0.48, w, h * (0.60 + 0.02 * desplazamiento))
      ..lineTo(w, h * 0.68)
      ..quadraticBezierTo(w * 0.78, h * 0.58, w * 0.55, h * (0.80 + 0.02 * desplazamiento))
      ..close();
    canvas.drawPath(veta, Paint()..color = AppColors.amarillo.withValues(alpha: 0.09));
  }

  @override
  bool shouldRepaint(_PintorOndas oldDelegate) =>
      oldDelegate.fase != fase || oldDelegate.color != color;
}
