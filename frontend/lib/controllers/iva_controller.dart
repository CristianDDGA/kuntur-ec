import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/tarifa_iva.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Controlador (C) del panel de IVA: carga la tarifa vigente y el historial, y permite programar una nueva.
class IvaController extends AsyncNotifier<ResumenIva> {
  @override
  Future<ResumenIva> build() => _conSesion(() => ref.read(ivaServiceProvider).consultar());

  /// Programa una tarifa nueva. Si el servidor la rechaza (400/409/403) el error se propaga a la
  /// pantalla para mostrarlo en el formulario, y la lista que ya se veía no se pierde.
  Future<void> cambiar({required String porcentaje, required DateTime vigenteDesde}) async {
    await _conSesion(() => ref.read(ivaServiceProvider).cambiar(porcentaje: porcentaje, vigenteDesde: vigenteDesde));
    ref.invalidateSelf();
    await future;
  }

  Future<T> _conSesion<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on UnauthorizedFailure {
      await ref.read(sesionControllerProvider.notifier).sesionExpirada();
      rethrow;
    }
  }
}

final ivaControllerProvider = AsyncNotifierProvider.autoDispose<IvaController, ResumenIva>(
  IvaController.new,
  retry: (_, _) => null,
);
