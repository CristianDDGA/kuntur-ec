import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Controlador (C) del detalle de un vuelo. Un estado por `id`; se descarta al salir.
class VueloDetalleController extends AsyncNotifier<Vuelo> {
  VueloDetalleController(this.id);

  final int id;

  @override
  Future<Vuelo> build() async {
    try {
      return await ref.read(vueloServiceProvider).obtener(id);
    } on UnauthorizedFailure {
      await ref.read(sesionControllerProvider.notifier).sesionExpirada();
      rethrow;
    }
  }
}

final vueloDetalleControllerProvider =
    AsyncNotifierProvider.autoDispose.family<VueloDetalleController, Vuelo, int>(
  VueloDetalleController.new,
  retry: (_, _) => null,
);
