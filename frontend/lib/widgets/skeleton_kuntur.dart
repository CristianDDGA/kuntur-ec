import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Bloque de estructura que ocupa el lugar del contenido mientras carga,
/// evitando saltos visuales de layout.
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

/// Aparición finita de opacidad dentro del presupuesto `AppMotion.mediaDe` (sin bucles infinitos).
class _Latido extends StatelessWidget {
  const _Latido({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.55, end: 1),
        duration: AppMotion.mediaDe(context),
        curve: AppMotion.curvaSalidaFuerte,
        builder: (context, valor, hijo) => Opacity(opacity: valor, child: hijo),
        child: child,
      );
}

/// Esqueleto de una tarjeta de vuelo o gestión (código, ruta y precio).
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

/// Esqueleto estructurado para bloques KPI del panel de administración.
class SkeletonKpiResumen extends StatelessWidget {
  const SkeletonKpiResumen({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando resumen de ventas…',
        liveRegion: true,
        child: ExcludeSemantics(
          child: _Latido(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < 4; i++)
                      const SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Esqueleto(ancho: 110, alto: 22),
                            SizedBox(height: 6),
                            Esqueleto(ancho: 90, alto: 12),
                          ],
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

/// Esqueleto compacto de filas para listados de flota o historial.
class SkeletonListaFilas extends StatelessWidget {
  const SkeletonListaFilas({super.key, this.filas = 3});

  final int filas;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando listado…',
        liveRegion: true,
        child: ExcludeSemantics(
          child: _Latido(
            child: Column(
              children: [
                for (var i = 0; i < filas; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Esqueleto(ancho: 72, alto: 16),
                        SizedBox(width: 12),
                        Expanded(child: Esqueleto(alto: 14)),
                        SizedBox(width: 12),
                        Esqueleto(ancho: 64, alto: 16),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
