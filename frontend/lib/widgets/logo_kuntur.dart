import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';

/// Logo: un cóndor andino (kuntur, el ave nacional del Ecuador) con las alas abiertas,
/// dibujado a mano sobre un cuadrado redondeado con el degradado de marca.
class LogoKuntur extends StatelessWidget {
  const LogoKuntur({super.key, this.tamano = 56});

  final double tamano;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Logo de ${AppConfig.appName}',
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            gradient: AppGradients.boton,
            borderRadius: BorderRadius.circular(tamano * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.azul.withValues(alpha: 0.30),
                blurRadius: tamano * 0.3,
                offset: Offset(0, tamano * 0.1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(tamano * 0.14),
            child: const CustomPaint(painter: _CondorPainter()),
          ),
        ),
      );
}

/// Nombre de la app con el logo: "Kuntur EC".
class MarcaKuntur extends StatelessWidget {
  const MarcaKuntur({super.key, this.tamanoLogo = 48, this.vertical = true, this.enOscuro = false});

  final double tamanoLogo;
  final bool vertical;

  /// Para usarla sobre un fondo oscuro (barra superior): texto blanco y "EC" en amarillo.
  final bool enOscuro;

  @override
  Widget build(BuildContext context) {
    final nombre = Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: tamanoLogo * 0.5,
          fontWeight: FontWeight.w800,
          color: enOscuro ? Colors.white : AppColors.textoPrincipal,
          letterSpacing: -0.3,
        ),
        children: [
          const TextSpan(text: 'Kuntur '),
          TextSpan(text: 'EC', style: TextStyle(color: enOscuro ? AppColors.amarillo : AppColors.azul)),
        ],
      ),
    );
    final logo = LogoKuntur(tamano: tamanoLogo);
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: [logo, SizedBox(height: tamanoLogo * 0.25), nombre])
        : Row(mainAxisSize: MainAxisSize.min, children: [logo, SizedBox(width: tamanoLogo * 0.25), nombre]);
  }
}

class _CondorPainter extends CustomPainter {
  const _CondorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja en una cuadrícula de 100 x 70 y se escala al tamaño disponible.
    final escala = size.width / 100;
    canvas
      ..translate(0, (size.height - 70 * escala) / 2)
      ..scale(escala);

    final blanco = Paint()..color = Colors.white;
    final dorado = Paint()..color = AppColors.amarillo;

    // Ala derecha con las "manos" (plumas primarias) típicas del cóndor; la izquierda es su espejo.
    final ala = Path()
      ..moveTo(50, 30)
      ..cubicTo(60, 20, 78, 14, 98, 24)
      ..lineTo(88, 28)
      ..lineTo(96, 34)
      ..lineTo(84, 36)
      ..lineTo(90, 43)
      ..lineTo(75, 41)
      ..lineTo(76, 49)
      ..lineTo(62, 43)
      ..cubicTo(57, 46, 53, 52, 50, 54)
      ..close();
    canvas.drawPath(ala, blanco);
    canvas
      ..save()
      ..translate(100, 0)
      ..scale(-1, 1)
      ..drawPath(ala, blanco)
      ..restore();

    // Cuerpo, cola y cabeza.
    canvas.drawOval(const Rect.fromLTWH(44.5, 24, 11, 32), blanco);
    canvas.drawPath(
      Path()
        ..moveTo(50, 52)
        ..lineTo(42, 68)
        ..lineTo(58, 68)
        ..close(),
      blanco,
    );
    canvas.drawCircle(const Offset(50, 21), 5.2, blanco);
    // Pico y collar dorado.
    canvas.drawPath(
      Path()
        ..moveTo(53.5, 19.5)
        ..lineTo(59, 22)
        ..lineTo(53.5, 24.5)
        ..close(),
      dorado,
    );
    canvas.drawOval(const Rect.fromLTWH(45, 25.5, 10, 3.6), dorado);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
