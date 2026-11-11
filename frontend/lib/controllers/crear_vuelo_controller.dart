import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';
import 'vuelos_controller.dart';

/// Controlador (C) del formulario "Nuevo vuelo" (solo administrador).
/// `AsyncData(vuelo)` = creado; `AsyncError` = el servidor lo rechazó; `null` = aún no se envía.
class CrearVueloController extends AsyncNotifier<Vuelo?> {
  @override
  FutureOr<Vuelo?> build() => null;

  /// Devuelve el vuelo creado, o `null` si falló (el error queda en el estado).
  Future<Vuelo?> crear(NuevoVuelo datos) async {
    // Doble toque: si ya hay un envío en curso se ignora este, así nunca se crean dos vuelos.
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      try {
        return await ref.read(vueloServiceProvider).crear(datos);
      } on UnauthorizedFailure {
        await ref.read(sesionControllerProvider.notifier).sesionExpirada();
        rethrow;
      }
    });
    if (!ref.mounted) return resultado.value;
    state = resultado;
    if (resultado.hasValue) ref.invalidate(vuelosControllerProvider); // la lista debe mostrar el nuevo vuelo
    return resultado.value;
  }
}

final crearVueloControllerProvider = AsyncNotifierProvider.autoDispose<CrearVueloController, Vuelo?>(
  CrearVueloController.new,
  retry: (_, _) => null,
);
