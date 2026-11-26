import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import '../config/providers.dart';
import '../controllers/google_controller.dart';
import '../models/fallo.dart';
import 'aviso.dart';

/// «O continúe con Google»: se muestra en el login y en el registro. Si Google no está disponible
/// no ocupa lugar. Respeta [habilitado] para evitar envíos concurrentes mientras el formulario guarda.
class BotonGoogle extends ConsumerStatefulWidget {
  const BotonGoogle({super.key, this.habilitado = true});

  final bool habilitado;

  @override
  ConsumerState<BotonGoogle> createState() => _BotonGoogleState();
}

class _BotonGoogleState extends ConsumerState<BotonGoogle> {
  StreamSubscription<String>? _tokens;

  @override
  void initState() {
    super.initState();
    final google = ref.read(proveedorGoogleProvider);
    if (!google.disponible) return;
    _tokens = google.tokens.listen((token) => ref.read(googleLoginControllerProvider.notifier).ingresar(token));
    unawaited(google.iniciar().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final google = ref.watch(proveedorGoogleProvider);
    if (!google.disponible) return const SizedBox.shrink();

    final estado = ref.watch(googleLoginControllerProvider);
    final cargando = estado.isLoading;
    final error = estado.hasError && !cargando ? mensajeDeError(estado.error!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('o continúe con', style: AppTextStyles.nota),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 6),
        if (cargando)
          const Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3)))
        else
          IgnorePointer(
            ignoring: !widget.habilitado,
            child: AnimatedOpacity(
              opacity: widget.habilitado ? 1.0 : 0.45,
              duration: AppMotion.opacidadDe(context),
              child: Center(child: SizedBox(height: 44, child: google.boton())),
            ),
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AvisoInline(texto: error),
        ],
      ],
    );
  }
}
