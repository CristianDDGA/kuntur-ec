import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Bloque gris que ocupa el lugar del contenido mientras carga.
///
/// Se usa dentro de [SkeletonListaTarjetas] y [SkeletonDetalle]: mostrar la
/// estructura de la pantalla evita el salto visual y comunica la espera antes
/// de que lleguen los datos (Apple HIG, `loading.md › Showing progress`: dar
/// señal de progreso cuanto antes y mantener el contexto de la pantalla).
class Esqueleto extends StatelessWidget {
  const Esqueleto({super.key, this.ancho, this.alto = 14, this.radio = 8});

  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) => Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: AppColors.divisor,
          borderRadius: BorderRadius.circular(radio),
        ),
      );
}

/// Aparece con un latido suave de opacidad (una sola vez, sin bucles infinitos:
/// así los tests y la batería no se quedan esperando frames para siempre).
class _Latido extends StatelessWidget {
  const _Latido({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.45, end: 1),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, valor, hijo) => Opacity(opacity: valor, child: hijo),
        child: child,
      );
}

/// Esqueleto de una tarjeta de vuelo (título, ruta y precio).
class SkeletonTarjeta extends StatelessWidget {
  const SkeletonTarjeta({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.tarjeta,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Esqueleto(ancho: 64, alto: 18, radio: 6),
                SizedBox(width: 10),
                Esqueleto(ancho: 96),
                Spacer(),
                Esqueleto(ancho: 64, alto: 20, radio: 10),
              ],
            ),
            SizedBox(height: 14),
            Esqueleto(ancho: 180, alto: 22),
            SizedBox(height: 10),
            Esqueleto(ancho: 240, alto: 12),
          ],
        ),
      );
}

/// Lista de esqueletos de tarjeta para la carga inicial de un catálogo.
class SkeletonListaTarjetas extends StatelessWidget {
  const SkeletonListaTarjetas({super.key, this.cantidad = 4});

  final int cantidad;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando contenido…',
        liveRegion: true,
        child: ExcludeSemantics(
          child: _Latido(
            child: Column(
              children: [
                for (var i = 0; i < cantidad; i++)
                  const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonTarjeta()),
              ],
            ),
          ),
        ),
      );
}

/// Esqueleto para una pantalla de detalle (cabecera + bloques de datos).
class SkeletonDetalle extends StatelessWidget {
  const SkeletonDetalle({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando contenido…',
        liveRegion: true,
        child: ExcludeSemantics(
          child: _Latido(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.tarjeta,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Esqueleto(ancho: 120, alto: 20),
                      SizedBox(height: 12),
                      Esqueleto(ancho: 220),
                      SizedBox(height: 8),
                      Esqueleto(ancho: 160),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final ancho in <double>[280, 200, 240])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Esqueleto(ancho: ancho, alto: 14),
                  ),
              ],
            ),
          ),
        ),
      );
}
