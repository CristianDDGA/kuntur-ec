import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../models/fallo.dart';
import '../widgets/aviso.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/logo_kuntur.dart';

/// Pantalla de carga mientras se valida la sesión guardada con el servidor.
/// Una sola entrada coordinada y sin duplicar la marca `Kuntur EC`.
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
              child: SingleChildScrollView(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: AppMotion.mediaDe(context),
                  curve: AppMotion.curvaSalidaFuerte,
                  builder: (context, avance, hijo) => Opacity(
                    opacity: (0.25 + 0.75 * avance).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - avance) * 10),
                      child: hijo,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HeroIsometricoAndes(alto: 164),
                      const SizedBox(height: 20),
                      const MarcaKuntur(),
                      const SizedBox(height: 28),
                      if (error == null) ...[
                        const SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2.8)),
                        const SizedBox(height: 14),
                        const Text('Verificando su sesión…', style: AppTextStyles.cuerpo),
                      ] else ...[
                        AvisoInline(texto: error),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => ref.invalidate(sesionControllerProvider),
                              child: const Text('Reintentar'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(sesionControllerProvider.notifier).continuarSinSesion();
                                context.go(AppRoutes.login);
                              },
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
        ),
      ),
    );
  }
}
