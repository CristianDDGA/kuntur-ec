import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import 'sesion_controller.dart';

/// Controlador (C) de «Iniciar sesión con Google»: envía el `id_token` al servidor y, si lo acepta, abre la sesión.
/// Sirve igual para entrar y para registrarse: el servidor crea la cuenta si todavía no existe.
class GoogleLoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> ingresar(String idToken) async {
    if (state.isLoading) return; // un solo intento a la vez
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final sesion = await ref.read(authServiceProvider).loginGoogle(idToken);
      ref.read(sesionControllerProvider.notifier).abrir(sesion.usuario);
    });
    if (ref.mounted) state = resultado;
  }
}

final googleLoginControllerProvider = AsyncNotifierProvider.autoDispose<GoogleLoginController, void>(
  GoogleLoginController.new,
  retry: (_, _) => null,
);
