import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/validadores.dart';
import 'verificacion_controller.dart';

/// Controlador (C) de la pantalla de registro.
/// Crea la cuenta (sin verificar) y deja anotado que falta confirmar el correo: la pantalla siguiente pide el código
/// y, al confirmarlo, inicia sesión con estas mismas credenciales.
class RegistroController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si la cuenta se creó y hay que pasar a confirmar el correo.
  Future<bool> registrar({
    required String nombre,
    required String cedula,
    required String correo,
    required String password,
  }) async {
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final creada = await ref.read(authServiceProvider).registrar(
            nombre: Validadores.normalizarNombre(nombre),
            cedula: cedula,
            correo: correo,
            password: password,
          );
      // Si el correo con el código no salió, la pantalla siguiente pide uno nuevo apenas se abre.
      ref.read(verificacionPendienteProvider.notifier).iniciar(
            VerificacionPendiente(correo: correo.trim(), password: password, enviarAlEntrar: !creada.codigoEnviado),
          );
    });
    if (ref.mounted) state = resultado;
    return resultado.hasValue;
  }
}

final registroControllerProvider = AsyncNotifierProvider.autoDispose<RegistroController, void>(
  RegistroController.new,
  retry: (_, _) => null,
);
