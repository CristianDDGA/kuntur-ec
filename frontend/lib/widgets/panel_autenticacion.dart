import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import 'franja_tricolor.dart';
import 'logo_kuntur.dart';

/// Plantilla de las pantallas de acceso (login y registro): marca arriba y el
/// formulario en una tarjeta centrada sobre un fondo suave, como en APE8,
/// pero con la paleta de Ecuador y la franja tricolor como único adorno.
class PanelAutenticacion extends StatelessWidget {
  const PanelAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
  });

  final String titulo;
  final String subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.fondo),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MarcaKuntur(),
                      const SizedBox(height: 28),
                      // Entrada suave del formulario (una sola vez, respetando Reduce Motion).
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: AppMotion.mediaDe(context),
                        curve: AppMotion.curvaEntrada,
                        builder: (context, avance, hijo) => Opacity(
                          opacity: avance,
                          child: Transform.translate(
                            offset: Offset(0, (1 - avance) * 14),
                            child: hijo,
                          ),
                        ),
                        child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: AppDecorations.tarjeta,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FranjaTricolor(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(header: true, child: Text(titulo, style: AppTextStyles.titulo)),
                                  const SizedBox(height: 6),
                                  Text(subtitulo, style: AppTextStyles.cuerpo),
                                  const SizedBox(height: 24),
                                  child,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Vuelos nacionales por todo el Ecuador', style: AppTextStyles.nota),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
