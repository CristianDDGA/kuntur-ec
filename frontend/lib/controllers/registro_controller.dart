import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Controlador (C) de la pantalla de registro.
/// Crea la cuenta y, si sale bien, inicia sesión de inmediato con las mismas credenciales.
class RegistroController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> registrar({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final auth = ref.read(authServiceProvider);
      await auth.registrar(
        nombre: Validadores.normalizarNombre(nombre),
        correo: correo,
        password: password,
      );
      try {
        final sesion = await auth.login(correo: correo, password: password);
        ref.read(sesionControllerProvider.notifier).abrir(sesion.usuario);
      } on Failure {
        // La cuenta ya existe: el usuario solo debe iniciar sesión a mano.
        throw const ServerFailure(
          'Su cuenta fue creada, pero no se pudo iniciar sesión automáticamente. '
          'Inicie sesión con su correo y contraseña.',
          statusCode: 200,
          codigo: 'cuenta_creada',
        );
      }
    });
    if (ref.mounted) state = resultado;
  }
}

final registroControllerProvider = AsyncNotifierProvider.autoDispose<RegistroController, void>(
  RegistroController.new,
  retry: (_, _) => null,
);
