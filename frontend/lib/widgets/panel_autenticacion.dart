import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import 'franja_tricolor.dart';
import 'isometric_kuntur.dart';
import 'liquid_morph.dart';
import 'logo_kuntur.dart';

/// Plantilla simétrica de las pantallas de acceso (login, registro, verificación,
/// recuperación y perfil): una única entrada coordinada en la tarjeta (`220 ms`),
/// título estático legible y controles de navegación con área táctil mínima de 44×44 pt.
class PanelAutenticacion extends StatelessWidget {
  const PanelAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.faseLiquida = 0,
    this.mostrarVolver = true,
  });

  final String titulo;
  final String subtitulo;
  final Widget child;
  final double faseLiquida;

  /// Se desactiva en flujos obligatorios con sesión iniciada (p. ej. completar cédula)
  /// donde volver a `/` redirigiría en bucle a la misma pantalla.
  final bool mostrarVolver;

  Widget _botonVolver(BuildContext context, {bool compacta = false}) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          backgroundColor: AppColors.superficie.withValues(alpha: 0.92),
          side: BorderSide(color: AppColors.borde.withValues(alpha: 0.95)),
          minimumSize: Size(44, compacta ? 36 : 42),
          tapTargetSize: compacta ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compacta ? 6 : 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 17),
        label: const Text('Volver al inicio'),
        onPressed: () => Navigator.of(context).canPop()
            ? Navigator.of(context).pop()
            : GoRouter.of(context).go('/'),
      );

  Widget _logo(BuildContext context, {required double tamano, bool compacta = false}) {
    final marca = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compacta ? 2 : 4),
      child: MarcaKuntur(tamanoLogo: tamano, vertical: false),
    );
    if (!mostrarVolver) return marca;
    return Semantics(
      button: true,
      label: 'Kuntur EC, ir al inicio',
      onTap: () => GoRouter.of(context).go('/'),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => GoRouter.of(context).go('/'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compacta ? 38 : 44, minWidth: 44),
          child: Center(widthFactor: 1, child: marca),
        ),
      ),
    );
  }

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
                  final volverFlotante = mostrarVolver && caja.maxWidth >= 720 && caja.maxHeight >= 540;
                  final rellenoVertical = compacta ? 4.0 : 14.0;
                  final rellenoHorizontal = caja.maxWidth < 440 ? 14.0 : 20.0;
                  final rellenoTarjeta = compacta
                      ? const EdgeInsets.fromLTRB(18, 10, 18, 8)
                      : const EdgeInsets.fromLTRB(26, 18, 26, 18);

                  final columnaCentral = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (mostrarVolver && !volverFlotante) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _botonVolver(context, compacta: compacta),
                          ),
                          SizedBox(height: compacta ? 2 : 6),
                        ],
                        _logo(context, tamano: compacta ? 26 : 38, compacta: compacta),
                        SizedBox(height: compacta ? 4 : 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: AppMotion.mediaDe(context),
                          curve: AppMotion.curvaSalidaFuerte,
                          builder: (context, avance, hijo) => Opacity(
                            opacity: (0.2 + 0.8 * avance).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, (1 - avance) * 10),
                              child: hijo,
                            ),
                          ),
                          child: MarcoIsometrico25D(
                            relleno: EdgeInsets.zero,
                            radio: 20,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
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
                                          child: Text(
                                            titulo,
                                            style: AppTextStyles.titulo.copyWith(fontSize: compacta ? 21 : 26),
                                          ),
                                        ),
                                        SizedBox(height: compacta ? 2 : 6),
                                        Text(subtitulo, style: AppTextStyles.cuerpo),
                                        SizedBox(height: compacta ? 10 : 18),
                                        child,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compacta ? 6 : 14),
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
