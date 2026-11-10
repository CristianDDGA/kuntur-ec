import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import 'sesion_controller.dart';

/// Controlador (C) de la pantalla de inicio de sesión.
/// El estado indica si se está enviando (`loading`) o si el último intento falló (`error`).
class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> ingresar({required String correo, required String password}) async {
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final sesion = await ref.read(authServiceProvider).login(correo: correo, password: password);
      ref.read(sesionControllerProvider.notifier).abrir(sesion.usuario);
    });
    if (ref.mounted) state = resultado;
  }
}

/// `autoDispose`: al salir de la pantalla se olvida el error, así no reaparece al volver.
final loginControllerProvider = AsyncNotifierProvider.autoDispose<LoginController, void>(
  LoginController.new,
  retry: (_, _) => null,
);
