import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Tono de la confirmación: una acción normal o una acción destructiva.
enum EstiloConfirmacion { normal, destructiva }

/// Confirmación de Kuntur EC, una sola forma en toda la app.
///
/// En móvil se presenta como hoja modal (con asa de arrastre) y en pantallas
/// anchas como diálogo contenido; en ambos casos la acción **segura** es la
/// primaria y la destructiva vive separada y nunca con el rol primario
/// (Apple HIG, `buttons.md › Role`: la acción destructiva no lleva el rol
/// primario; `modality.md` pide una salida clara y una tarea corta).
///
/// Devuelve `true` solo si la persona confirma.
Future<bool> mostrarConfirmacionKuntur(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
  EstiloConfirmacion estilo = EstiloConfirmacion.normal,
  IconData? icono,
}) async {
  final destructiva = estilo == EstiloConfirmacion.destructiva;

  Widget contenido(BuildContext ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 30, color: destructiva ? AppColors.error : AppColors.azul),
                const SizedBox(height: 8),
              ],
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 8),
              Text(mensaje, textAlign: TextAlign.center, style: AppTextStyles.cuerpo),
              const SizedBox(height: 20),
              if (destructiva) ...[
                // La salida segura es la acción primaria; la destructiva queda aparte.
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(textoCancelar),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    textoConfirmar,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                  ),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(textoConfirmar),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(textoCancelar),
                ),
              ],
            ],
          ),
        ),
      );

  final ancho = MediaQuery.sizeOf(context).width;
  final altoMaximo = MediaQuery.sizeOf(context).height * 0.85;
  final resultado = ancho >= 720
      ? await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: AppColors.superficie,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(child: contenido(ctx)),
            ),
          ),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          // Permite crecer más allá del 56 % y desplazarse con texto ampliado.
          isScrollControlled: true,
          backgroundColor: AppColors.superficie,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: altoMaximo),
            child: SingleChildScrollView(child: contenido(ctx)),
          ),
        );
  return resultado ?? false;
}
