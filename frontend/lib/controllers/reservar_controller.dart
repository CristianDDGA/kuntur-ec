import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/reserva.dart';
import 'con_sesion.dart';
import 'mapa_asientos_controller.dart';
import 'reservas_controller.dart';
import 'vuelo_detalle_controller.dart';
import 'vuelos_controller.dart';

/// Controlador (C) del botón "Reservar" del detalle de un vuelo.
/// `AsyncData(reserva)` = creada; `AsyncError` = el servidor la rechazó; `null` = aún no se envía.
class ReservarController extends AsyncNotifier<Reserva?> {
  @override
  FutureOr<Reserva?> build() => null;

  /// Devuelve la reserva creada, o `null` si falló (el error queda en el estado) o ya había un envío en curso.
  Future<Reserva?> reservar({required int vueloId, required List<String> asientos}) async {
    if (state.isLoading) return null; // doble toque: una sola reserva
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(
      () => conSesion(ref, () => ref.read(reservaServiceProvider).crear(vueloId: vueloId, asientos: asientos)),
    );
    if (!ref.mounted) return resultado.value;
    state = resultado;
    // Los asientos del vuelo cambiaron y el historial tiene una reserva nueva: se vuelven a pedir.
    ref.invalidate(vuelosControllerProvider);
    ref.invalidate(vueloDetalleControllerProvider(vueloId));
    ref.invalidate(mapaAsientosControllerProvider(vueloId));
    if (resultado.hasValue) {
      ref.read(paginaReservasProvider.notifier).primera();
      ref.invalidate(reservasControllerProvider);
    }
    return resultado.value;
  }
}

final reservarControllerProvider = AsyncNotifierProvider.autoDispose<ReservarController, Reserva?>(
  ReservarController.new,
  retry: (_, _) => null,
);
