import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/resumen_ventas.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Controlador (C) del resumen de ventas del panel de administración.
final resumenVentasProvider = FutureProvider.autoDispose<ResumenVentas>((ref) async {
  try {
    return await ref.read(reservaServiceProvider).resumenVentas();
  } on UnauthorizedFailure {
    await ref.read(sesionControllerProvider.notifier).sesionExpirada();
    rethrow;
  }
});
