import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import 'sesion_controller.dart';

/// Mensaje que el login muestra después de cambiar la contraseña.
const mensajeClaveActualizada = 'Contraseña actualizada. Inicie sesión con la nueva contraseña.';

/// Controlador (C) del primer paso de "Olvidé mi contraseña": pide el código al correo.
class SolicitarRecuperacionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si el servidor aceptó la solicitud (responde igual exista o no la cuenta).
  Future<bool> solicitar(String correo) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() => ref.read(authServiceProvider).solicitarRecuperacion(correo: correo));
    if (ref.mounted) state = resultado;
    return resultado.hasValue;
  }
}

final solicitarRecuperacionControllerProvider =
    AsyncNotifierProvider.autoDispose<SolicitarRecuperacionController, void>(
  SolicitarRecuperacionController.new,
  retry: (_, _) => null,
);

/// Controlador (C) del segundo paso: cambia la contraseña con el código recibido.
class RestablecerClaveController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si la contraseña quedó cambiada; deja un aviso para que el login lo muestre.
  Future<bool> restablecer({required String correo, required String codigo, required String password}) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(
      () => ref.read(authServiceProvider).restablecerClave(correo: correo, codigo: codigo, password: password),
    );
    if (resultado.hasValue) ref.read(avisoLoginProvider.notifier).mostrar(mensajeClaveActualizada);
    if (ref.mounted) state = resultado;
    return resultado.hasValue;
  }
}

final restablecerClaveControllerProvider = AsyncNotifierProvider.autoDispose<RestablecerClaveController, void>(
  RestablecerClaveController.new,
  retry: (_, _) => null,
);
