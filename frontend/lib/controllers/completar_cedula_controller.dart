import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import 'con_sesion.dart';
import 'sesion_controller.dart';

/// Controlador (C) de «Complete su perfil»: guarda la cédula de una cuenta que no la tiene (p. ej. creada con Google).
class CompletarCedulaController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si el servidor la aceptó; entonces la sesión ya tiene la cédula y el router deja pasar.
  Future<bool> guardar(String cedula, {String? nombre}) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final usuario = await conSesion(ref, () => ref.read(authServiceProvider).completarCedula(cedula, nombre: nombre));
      ref.read(sesionControllerProvider.notifier).actualizarUsuario(usuario);
    });
    if (ref.mounted) state = resultado;
    return resultado.hasValue;
  }
}

final completarCedulaControllerProvider = AsyncNotifierProvider.autoDispose<CompletarCedulaController, void>(
  CompletarCedulaController.new,
  retry: (_, _) => null,
);
