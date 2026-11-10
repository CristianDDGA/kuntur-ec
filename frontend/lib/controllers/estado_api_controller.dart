import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/estado_servicio.dart';

/// Controlador (C de MVC) de la pantalla de estado de la API.
/// Mantiene el estado (cargando / datos / error) y expone las acciones de la vista.
class EstadoApiController extends AsyncNotifier<EstadoServicio> {
  @override
  Future<EstadoServicio> build() => _consultar();

  Future<void> reintentar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_consultar);
  }

  Future<EstadoServicio> _consultar() => ref.read(sistemaServiceProvider).consultarEstado();
}

/// `retry: null`: sin reintentos automáticos; el usuario reintenta con el botón.
final estadoApiControllerProvider = AsyncNotifierProvider<EstadoApiController, EstadoServicio>(
  EstadoApiController.new,
  retry: (_, _) => null,
);
