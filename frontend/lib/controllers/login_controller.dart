import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';
import 'verificacion_controller.dart';

/// Controlador (C) de la pantalla de inicio de sesión.
/// El estado indica si se está enviando (`loading`) o si el último intento falló (`error`).
class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si las credenciales son correctas pero falta confirmar el correo: no hay error que mostrar, la pantalla
  /// lleva a pedir el código.
  Future<bool> ingresar({required String correo, required String password}) async {
    state = const AsyncLoading();
    var faltaVerificar = false;
    final resultado = await AsyncValue.guard(() async {
      try {
        final sesion = await ref.read(authServiceProvider).login(correo: correo, password: password);
        ref.read(sesionControllerProvider.notifier).abrir(sesion.usuario);
      } on ServerFailure catch (e) {
        if (e.statusCode != 403 || e.codigo != 'correo_no_verificado') rethrow;
        faltaVerificar = true;
        // El código anterior pudo vencer: la pantalla de verificación pide uno nuevo al abrirse.
        ref.read(verificacionPendienteProvider.notifier).iniciar(
              VerificacionPendiente(correo: correo.trim(), password: password, enviarAlEntrar: true),
            );
      }
    });
    if (ref.mounted) state = resultado;
    return faltaVerificar;
  }
}

/// `autoDispose`: al salir de la pantalla se olvida el error, así no reaparece al volver.
final loginControllerProvider = AsyncNotifierProvider.autoDispose<LoginController, void>(
  LoginController.new,
  retry: (_, _) => null,
);
