import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/logo_kuntur.dart';

/// Pantalla de carga mientras se valida la sesión guardada con el servidor.
/// Si el servidor no responde, permite reintentar o continuar hacia el login.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionControllerProvider);
    final error = sesion.hasError && !sesion.isLoading ? mensajeDeError(sesion.error!) : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.fondo),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MarcaKuntur(),
                  const SizedBox(height: 32),
                  if (error == null) ...[
                    const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                    const SizedBox(height: 14),
                    const Text('Verificando su sesión…', style: AppTextStyles.cuerpo),
                  ] else ...[
                    AvisoInline(texto: error),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () => ref.invalidate(sesionControllerProvider),
                          child: const Text('Reintentar'),
                        ),
                        TextButton(
                          onPressed: ref.read(sesionControllerProvider.notifier).continuarSinSesion,
                          child: const Text('Ir a iniciar sesión'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
