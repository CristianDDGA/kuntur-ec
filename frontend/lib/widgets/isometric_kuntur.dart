import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Motores de **diseño isométrico 2.5D** de Kuntur EC.
///
/// Todo se dibuja con `CustomPainter` (vectorial, sin assets) y se anima con
/// animaciones FINITAS gobernadas por [AppMotion]; ninguna usa bucles infinitos,
/// así `pumpAndSettle()` no se cuelga y Reduce Motion devuelve `Duration.zero`.

/// Ilustración hero de los Andes en 2.5D: relieves escalonados, pista aérea en
/// perspectiva dorada y el cóndor/avión ascendiendo.
class HeroIsometricoAndes extends StatelessWidget {
  const HeroIsometricoAndes({super.key, this.alto = 150, this.radio = 24});

  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: SizedBox(
          height: alto,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppMotion.heroeDe(context),
            curve: AppMotion.curvaEntrada,
            builder: (context, avance, _) => CustomPaint(painter: _PintorHeroAndes(avance: avance)),
          ),
        ),
      );
}

/// Cabecera 2.5D del fuselaje: proa biselada, parabrisas y nacimiento de alas.
///
/// Se posa sobre la cabina de asientos para dar sensación de profundidad sin
/// ocupar una franja grande de pantalla.
class ProaIsometricaAvion extends StatelessWidget {
  const ProaIsometricaAvion({super.key, this.alto = 58});

  final double alto;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: alto,
        width: double.infinity,
        child: const CustomPaint(painter: _PintorProa()),
      );
}

/// Envoltorio con bisel superior claro y sombra volumétrica desplazada.
///
/// Da a tarjetas y asientos la sensación física de una tecla/cojín 2.5D: en
/// reposo la sombra cae a 4 pt, al presionar se comprime a 1 pt y al estar
/// activo se eleva a 6 pt.
class MarcoIsometrico25D extends StatelessWidget {
  const MarcoIsometrico25D({
    super.key,
    required this.child,
    this.activo = false,
    this.presionado = false,
    this.radio = 20,
    this.color = AppColors.superficie,
    this.relleno = const EdgeInsets.all(16),
  });

  final Widget child;
  final bool activo;
  final bool presionado;
  final double radio;
  final Color color;
  final EdgeInsetsGeometry relleno;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: AppMotion.rapidaDe(context),
        curve: AppMotion.curvaTactil,
        padding: relleno,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radio),
          border: Border.all(color: AppColors.borde.withValues(alpha: 0.9), width: 1),
          boxShadow: [
            // Luz superior + sombra inferior: lectura de bisel sin romper el borderRadius.
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.55),
              blurRadius: 0,
              offset: const Offset(0, -1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: activo ? 0.13 : 0.08),
              blurRadius: activo ? 18 : 10,
              offset: Offset(0, presionado ? 1 : (activo ? 6 : 4)),
            ),
          ],
        ),
        child: child,
      );
}

/// Butaca isométrica 2.5D: cabezal, respaldo biselado, cojín en perspectiva y
/// numero del asiento. Es solo el dibujo: la interacción la pone [AsientoBoton].
class AsientoIsometrico3D extends StatelessWidget {
  const AsientoIsometrico3D({
    super.key,
    required this.numero,
    this.fondo = AppColors.superficie,
    this.borde = AppColors.azul,
    this.texto = AppColors.azul,
    this.seleccionado = false,
    this.ocupado = false,
    this.atenuado = false,
  });

  final String numero;
  final Color fondo;
  final Color borde;
  final Color texto;
  final bool seleccionado;
  final bool ocupado;
  final bool atenuado;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: atenuado ? 0.45 : 1,
        child: TweenAnimationBuilder<double>(
          key: ValueKey<bool>(seleccionado),
          tween: Tween<double>(begin: 0.9, end: 1),
          duration: AppMotion.rapidaDe(context),
          curve: AppMotion.curvaTactil,
          builder: (context, avance, hijo) => Transform.scale(scale: avance, child: hijo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _PintorButaca(fondo: fondo, borde: borde, seleccionado: seleccionado),
              ),
              Center(
                child: ocupado
                    ? Icon(Icons.close, size: 16, color: texto)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          numero,
                          style: TextStyle(color: texto, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
}

/// Tarjeta de métrica con plinto isométrico (panel de administración).
class BloqueMetricaIsometrico extends StatelessWidget {
  const BloqueMetricaIsometrico({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.pie,
    this.destacado = false,
  });

  final String etiqueta;
  final Widget valor;
  final Widget? pie;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: AppDecorations.tarjeta,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _PintorPlinto(destacado: destacado)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: AppTextStyles.etiqueta),
                  const SizedBox(height: 6),
                  valor,
                  if (pie != null) ...[
                    const SizedBox(height: 4),
                    pie!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Arco de vuelo 2.5D con estela discontinua y sombra de cordillera.
///
/// Sustituye al `Divider` plano de la ruta en las tarjetas de vuelo.
class ArcoVueloIsometrico extends StatelessWidget {
  const ArcoVueloIsometrico({super.key, this.alto = 52, this.color = AppColors.cielo});

  final double alto;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: alto,
        width: double.infinity,
        child: CustomPaint(painter: _PintorArco(color: color)),
      );
}

// ---------------------------------------------------------------------------
// Pintores
// ---------------------------------------------------------------------------

class _PintorHeroAndes extends CustomPainter {
  _PintorHeroAndes({required this.avance});

  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fondo = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.azulNoche, AppColors.azul],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fondo);

    canvas.drawCircle(Offset(w * 0.78, h * 0.28), h * 0.10, Paint()..color = AppColors.amarillo.withValues(alpha: 0.30));

    // Tres capas de montañas con cara iluminada (lectura isométrica por planos).
    void montana(double base, Color color, double altura, double desfase) {
      final cumbre = base - altura;
      final p = Path()
        ..moveTo(-w * 0.1, base)
        ..lineTo(w * 0.22 + desfase, cumbre)
        ..lineTo(w * 0.42 + desfase, base)
        ..lineTo(w * 0.70 + desfase, base - altura * 0.75)
        ..lineTo(w * 1.1, base)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
      final cara = Path()
        ..moveTo(w * 0.22 + desfase, cumbre)
        ..lineTo(w * 0.42 + desfase, base)
        ..lineTo(w * 0.30 + desfase, base)
        ..close();
      canvas.drawPath(cara, Paint()..color = Colors.white.withValues(alpha: 0.07));
    }

    montana(h * 1.02, AppColors.azulNoche, h * 0.50, 0);
    montana(h * 1.04, const Color(0xFF243A57), h * 0.36, w * 0.12);
    montana(h * 1.06, AppColors.cielo.withValues(alpha: 0.9), h * 0.24, w * 0.30);

    // Pista en perspectiva isométrica.
    final pista = Path()
      ..moveTo(w * 0.42, h)
      ..lineTo(w * 0.58, h)
      ..lineTo(w * 0.535, h * 0.54)
      ..lineTo(w * 0.465, h * 0.54)
      ..close();
    canvas.drawPath(pista, Paint()..color = const Color(0xFF16233A));

    final linea = Paint()
      ..color = AppColors.amarillo.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final t = i / 5;
      canvas.drawLine(
        Offset(w * 0.5, h * (0.97 - t * 0.40)),
        Offset(w * 0.5, h * (0.94 - t * 0.40)),
        linea,
      );
    }

    // Aviación: aparece elevándose desde abajo (movimiento isométrico ascendente).
    final opacidad = avance.clamp(0.0, 1.0);
    final centro = Offset(w * 0.5, h * 0.34 + (1 - opacidad) * h * 0.35);
    final ala = Paint()..color = AppColors.nieve.withValues(alpha: 0.92 * opacidad);
    canvas.drawPath(
      Path()
        ..moveTo(centro.dx, centro.dy)
        ..lineTo(centro.dx - w * 0.035, centro.dy - h * 0.022)
        ..lineTo(centro.dx, centro.dy + h * 0.012)
        ..lineTo(centro.dx + w * 0.035, centro.dy - h * 0.022)
        ..close(),
      ala,
    );
    canvas.drawLine(
      Offset(centro.dx, centro.dy + h * 0.016),
      Offset(centro.dx, centro.dy + h * 0.10),
      Paint()
        ..color = AppColors.amarillo.withValues(alpha: 0.55 * opacidad)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorHeroAndes oldDelegate) => oldDelegate.avance != avance;
}

class _PintorProa extends CustomPainter {
  const _PintorProa();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Alas laterales nacientes.
    final ala = Paint()..color = AppColors.cielo.withValues(alpha: 0.35);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.62)
        ..lineTo(w * 0.02, h * 0.86)
        ..lineTo(w * 0.24, h * 0.90)
        ..lineTo(w * 0.40, h * 0.72)
        ..close(),
      ala,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.70, h * 0.62)
        ..lineTo(w * 0.98, h * 0.86)
        ..lineTo(w * 0.76, h * 0.90)
        ..lineTo(w * 0.60, h * 0.72)
        ..close(),
      ala,
    );

    final fuselaje = Path()
      ..moveTo(w * 0.30, h)
      ..lineTo(w * 0.36, h * 0.34)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.64, h * 0.34)
      ..lineTo(w * 0.70, h)
      ..close();
    canvas.drawPath(
      fuselaje,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.azul, AppColors.azulNoche],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      fuselaje,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Cabina de mando: parabrisas con reflejo dorado.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.44, h * 0.30)
        ..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.56, h * 0.30)
        ..lineTo(w * 0.55, h * 0.48)
        ..lineTo(w * 0.45, h * 0.48)
        ..close(),
      Paint()..color = AppColors.amarillo.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(w * 0.45, h * 0.48),
      Offset(w * 0.55, h * 0.48),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PintorProa oldDelegate) => false;
}

class _PintorButaca extends CustomPainter {
  _PintorButaca({required this.fondo, required this.borde, required this.seleccionado});

  final Color fondo;
  final Color borde;
  final bool seleccionado;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radio = Radius.circular(w * 0.26);

    // Sombra física: al seleccionar, la butaca se eleva.
    final respaldo = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.80),
      radio,
    );
    canvas.drawRRect(
      respaldo.shift(Offset(0, seleccionado ? h * 0.09 : h * 0.05)),
      Paint()..color = Colors.black.withValues(alpha: seleccionado ? 0.18 : 0.10),
    );

    // Respaldo con bisel superior claro.
    canvas.drawRRect(respaldo, Paint()..color = fondo);
    canvas.drawRRect(
      respaldo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = borde.withValues(alpha: 0.9),
    );
    canvas.drawLine(
      Offset(w * 0.24, h * 0.16),
      Offset(w * 0.76, h * 0.16),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.6,
    );

    // Cabezal y cojín en perspectiva.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.14, w * 0.44, h * 0.16),
        Radius.circular(h * 0.08),
      ),
      Paint()..color = borde.withValues(alpha: 0.30),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, h * 0.74)
        ..lineTo(w * 0.34, h * 0.68)
        ..lineTo(w * 0.82, h * 0.74)
        ..lineTo(w * 0.66, h * 0.88)
        ..close(),
      Paint()..color = borde.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(_PintorButaca oldDelegate) =>
      oldDelegate.fondo != fondo || oldDelegate.borde != borde || oldDelegate.seleccionado != seleccionado;
}

class _PintorPlinto extends CustomPainter {
  _PintorPlinto({required this.destacado});

  final bool destacado;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final acento = destacado ? AppColors.amarillo : AppColors.cielo;
    // Plinto isométrico: cara superior, lateral y frontal.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.62, h * 0.82)
        ..lineTo(w * 0.80, h * 0.74)
        ..lineTo(w * 1.0, h * 0.84)
        ..lineTo(w * 0.82, h * 0.92)
        ..close(),
      Paint()..color = acento.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.62, h * 0.82)
        ..lineTo(w * 0.82, h * 0.92)
        ..lineTo(w * 0.82, h * 1.02)
        ..lineTo(w * 0.62, h * 0.92)
        ..close(),
      Paint()..color = AppColors.azul.withValues(alpha: 0.05),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.80, h * 0.74)
        ..lineTo(w * 1.0, h * 0.84)
        ..lineTo(w * 1.0, h * 0.98)
        ..lineTo(w * 0.80, h * 0.88)
        ..close(),
      Paint()..color = acento.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(_PintorPlinto oldDelegate) => oldDelegate.destacado != destacado;
}

class _PintorArco extends CustomPainter {
  _PintorArco({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inicio = Offset(w * 0.05, h * 0.74);
    final fin = Offset(w * 0.95, h * 0.74);
    final control = Offset(w * 0.5, -h * 0.15);

    final curva = Path()
      ..moveTo(inicio.dx, inicio.dy)
      ..quadraticBezierTo(control.dx, control.dy, fin.dx, fin.dy);

    // Trazo discontinuo (estela del vuelo).
    final metrica = curva.computeMetrics().first;
    final pintura = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final largo = metrica.length;
    var distancia = 0.0;
    while (distancia < largo) {
      canvas.drawPath(metrica.extractPath(distancia, math.min(distancia + 6, largo)), pintura);
      distancia += 11;
    }

    // Sombra de cordillera bajo el arco.
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(w * 0.18, h * 0.86)
        ..lineTo(w * 0.34, h)
        ..lineTo(w * 0.55, h * 0.90)
        ..lineTo(w * 0.78, h)
        ..close(),
      Paint()..color = AppColors.azul.withValues(alpha: 0.05),
    );

    // Avión inclinado al final del arco.
    final avion = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(fin.dx, fin.dy)
        ..lineTo(fin.dx - 9, fin.dy - 7)
        ..lineTo(fin.dx - 5, fin.dy - 1)
        ..lineTo(fin.dx - 9, fin.dy + 5)
        ..close(),
      avion,
    );
  }

  @override
  bool shouldRepaint(_PintorArco oldDelegate) => oldDelegate.color != color;
}
