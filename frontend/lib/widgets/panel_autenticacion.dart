import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import 'franja_tricolor.dart';
import 'isometric_kuntur.dart';
import 'kinetic_type.dart';
import 'liquid_morph.dart';
import 'logo_kuntur.dart';

/// Plantilla de las pantallas de acceso (login y registro): marca arriba y el
/// formulario en una tarjeta centrada sobre un fondo suave, como en APE8,
/// pero con la paleta de Ecuador y la franja tricolor como único adorno.
///
/// El fondo incorpora una onda líquida reactiva ([FondoLiquidMorph]) y sobre la
/// tarjeta se posa el hero isométrico de los Andes; la tarjeta usa el bisel 2.5D
/// de [MarcoIsometrico25D]. Todas las animaciones son finitas y respetan
/// «Reducir movimiento» vía [AppMotion].
class PanelAutenticacion extends StatelessWidget {
  const PanelAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.faseLiquida = 0,
  });

  final String titulo;
  final String subtitulo;
  final Widget child;

  /// Fase del fondo líquido: `0` en reposo, `1` cuando el foco está en una
  /// contraseña. La onda se desplaza suavemente sin distraer de la lectura.
  final double faseLiquida;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.fondo)),
            ),
            Positioned.fill(
              child: ExcludeSemantics(
                child: FondoLiquidMorph(fase: faseLiquida, color: AppColors.infoSuave),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MarcaKuntur(),
                        const SizedBox(height: 20),
                        // Ilustración 2.5D de los Andes sobre la tarjeta de acceso.
                        const HeroIsometricoAndes(alto: 130),
                        const SizedBox(height: 24),
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
                          child: MarcoIsometrico25D(
                            relleno: EdgeInsets.zero,
                            radio: 24,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FranjaTricolor(),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Semantics(
                                          header: true,
                                          child: TituloCinetico(titulo, estilo: AppTextStyles.titulo),
                                        ),
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
                        ),
                        const SizedBox(height: 18),
                        const Text('Vuelos nacionales por todo el Ecuador', style: AppTextStyles.nota),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
