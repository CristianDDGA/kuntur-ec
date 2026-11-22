import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/asientos.dart';
import 'con_sesion.dart';

/// Controlador (C) del mapa de asientos de un vuelo. Un estado por vuelo; se descarta al salir.
class MapaAsientosController extends AsyncNotifier<MapaAsientos> {
  MapaAsientosController(this.vueloId);

  final int vueloId;

  @override
  Future<MapaAsientos> build() => conSesion(ref, () => ref.read(vueloServiceProvider).mapaAsientos(vueloId));

  /// Vuelve a pedir el mapa (botón de actualizar, o tras un conflicto de asientos). Sin destello de carga:
  /// el mapa anterior se sigue viendo mientras llega el nuevo.
  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }
}

final mapaAsientosControllerProvider = AsyncNotifierProvider.autoDispose.family<MapaAsientosController, MapaAsientos, int>(
  MapaAsientosController.new,
  retry: (_, _) => null,
);
