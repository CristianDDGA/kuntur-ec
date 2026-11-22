import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/reserva.dart';
import '../services/api_exception.dart';
import '../services/reserva_service.dart';
import 'con_sesion.dart';
import 'mapa_asientos_controller.dart';
import 'reservas_controller.dart';
import 'vuelo_detalle_controller.dart';
import 'vuelos_controller.dart';

/// Controlador (C) del detalle de una reserva: la muestra y permite modificarla o cancelarla.
/// Un estado por `id`; se descarta al salir de la pantalla.
class ReservaDetalleController extends AsyncNotifier<Reserva> {
  ReservaDetalleController(this.id);

  final int id;
  bool _ocupado = false; // evita dos modificaciones/cancelaciones a la vez (doble toque)

  @override
  Future<Reserva> build() => conSesion(ref, () => ref.read(reservaServiceProvider).obtener(id));

  /// Deja la reserva con estos asientos. Los errores (asiento tomado, versión vieja, vuelo partido...) se
  /// propagan a la pantalla; si la versión quedó vieja se recarga la reserva para ver lo último.
  Future<void> modificar(List<String> asientos) => _accion((s, actual) async {
        try {
          return await s.modificar(id: id, asientos: asientos, version: actual.version);
        } on ServerFailure catch (e) {
          if (e.statusCode == 409) ref.invalidateSelf(); // otra pestaña la cambió: se recarga
          rethrow;
        }
      });

  Future<void> cancelar() => _accion((s, _) => s.cancelar(id));

  Future<void> _accion(Future<Reserva> Function(ReservaService servicio, Reserva actual) hacer) async {
    final actual = state.value;
    if (_ocupado || actual == null) return;
    _ocupado = true;
    try {
      final nueva = await conSesion(ref, () => hacer(ref.read(reservaServiceProvider), actual));
      if (!ref.mounted) return;
      state = AsyncData(nueva);
      // Cambió el historial y los asientos del vuelo.
      ref.invalidate(reservasControllerProvider);
      ref.invalidate(vuelosControllerProvider);
      ref.invalidate(vueloDetalleControllerProvider(nueva.vueloId));
      ref.invalidate(mapaAsientosControllerProvider(nueva.vueloId));
    } finally {
      _ocupado = false;
    }
  }
}

final reservaDetalleControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ReservaDetalleController, Reserva, int>(
  ReservaDetalleController.new,
  retry: (_, _) => null,
);
