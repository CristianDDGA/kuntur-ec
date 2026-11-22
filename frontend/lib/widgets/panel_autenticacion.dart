import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import 'franja_tricolor.dart';
import 'isometric_kuntur.dart';
import 'kinetic_type.dart';
import 'liquid_morph.dart';
import 'logo_kuntur.dart';

/// Plantilla de las pantallas de acceso (login y registro): logo centrado y el
/// formulario en una tarjeta simétrica sobre un fondo suave con onda líquida
/// reactiva ([FondoLiquidMorph]) y bisel 2.5D ([MarcoIsometrico25D]).
///
/// Todas las animaciones son finitas y respetan «Reducir movimiento» vía [AppMotion].
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

  Widget _botonVolver(BuildContext context, {bool compacta = false}) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textoSecundario,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: compacta ? 2 : 6),
          minimumSize: Size(0, compacta ? 34 : 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Volver al inicio'),
        onPressed: () => Navigator.of(context).canPop()
            ? Navigator.of(context).pop()
            : GoRouter.of(context).go('/'),
      );

  Widget _logo(BuildContext context, {required double tamano}) => Semantics(
        button: true,
        label: 'Ir al inicio',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => GoRouter.of(context).go('/'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: MarcaKuntur(tamanoLogo: tamano, vertical: false),
          ),
        ),
      );

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
              child: LayoutBuilder(
                builder: (context, caja) {
                  final compacta = caja.maxWidth < 440 || caja.maxHeight < 680;
                  // En pantallas amplias el botón de regreso va en la esquina superior izquierda
                  // para que el logo y el formulario queden completamente centrados y simétricos.
                  final volverFlotante = caja.maxWidth >= 720 && caja.maxHeight >= 540;
                  final rellenoVertical = compacta ? 8.0 : 16.0;
                  final rellenoHorizontal = caja.maxWidth < 440 ? 14.0 : 20.0;
                  final rellenoTarjeta = compacta
                      ? const EdgeInsets.fromLTRB(18, 14, 18, 14)
                      : const EdgeInsets.fromLTRB(26, 18, 26, 18);

                  final columnaCentral = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!volverFlotante) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _botonVolver(context, compacta: compacta),
                          ),
                          SizedBox(height: compacta ? 2 : 6),
                        ],
                        // Solo el logo centrado en el lugar de la antigua ilustración para
                        // mantener el acceso simétrico y sin scroll en pantalla completa.
                        _logo(context, tamano: compacta ? 32 : 40),
                        SizedBox(height: compacta ? 10 : 14),
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
                                    padding: rellenoTarjeta,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Semantics(
                                          header: true,
                                          child: TituloCinetico(
                                            titulo,
                                            estilo: AppTextStyles.titulo.copyWith(fontSize: compacta ? 23 : 26),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitulo, style: AppTextStyles.cuerpo),
                                        SizedBox(height: compacta ? 12 : 16),
                                        child,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compacta ? 8 : 12),
                        const Text(
                          'Vuelos nacionales por todo el Ecuador',
                          style: AppTextStyles.nota,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );

                  final contenidoDesplazable = SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: rellenoHorizontal, vertical: rellenoVertical),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (caja.maxHeight - rellenoVertical * 2).clamp(0.0, double.infinity),
                        minWidth: double.infinity,
                      ),
                      child: Center(child: columnaCentral),
                    ),
                  );

                  if (!volverFlotante) return contenidoDesplazable;

                  return Stack(
                    children: [
                      Positioned.fill(child: contenidoDesplazable),
                      Positioned(
                        top: 12,
                        left: 16,
                        child: _botonVolver(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}
