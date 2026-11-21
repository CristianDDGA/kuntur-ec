import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'aviso.dart';
import 'skeleton_kuntur.dart';

/// Estado vacío amigable: icono, título, explicación y (opcional) una acción.
///
/// Reemplaza las 3 tarjetas de "no hay nada" que se repetían con variaciones.
class VacioVista extends StatelessWidget {
  const VacioVista({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
    this.elevada = true,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final String? textoAccion;
  final VoidCallback? onAccion;

  /// `false` cuando el estado vacío vive dentro de otra tarjeta (evita doble superficie).
  final bool elevada;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: elevada ? AppDecorations.tarjeta : null,
        child: Column(
          children: [
            Icon(icono, size: 40, color: AppColors.textoSuave),
            const SizedBox(height: 10),
            Text(titulo, style: AppTextStyles.subtitulo, textAlign: TextAlign.center),
            if (mensaje != null) ...[
              const SizedBox(height: 4),
              Text(mensaje!, style: AppTextStyles.cuerpo, textAlign: TextAlign.center),
            ],
            if (textoAccion != null && onAccion != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAccion, child: Text(textoAccion!)),
            ],
          ],
        ),
      );
}

/// Error de carga con mensaje amigable y botón "Reintentar".
class ErrorVista extends StatelessWidget {
  const ErrorVista({super.key, required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvisoInline(texto: mensaje),
          const SizedBox(height: 12),
          Align(
            child: OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
}

/// Carga con esqueletos de la estructura real (menos brusca que un spinner).
class CargandoVista extends StatelessWidget {
  const CargandoVista({super.key, this.tarjetas = 4});

  final int tarjetas;

  @override
  Widget build(BuildContext context) => SkeletonListaTarjetas(cantidad: tarjetas);
}

/// Carga de una pantalla con estructura de detalle (cabecera + datos).
class CargandoDetalleVista extends StatelessWidget {
  const CargandoDetalleVista({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonDetalle();
}
