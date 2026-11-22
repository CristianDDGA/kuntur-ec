import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Ejecuta una llamada a la API; si el servidor responde 401 (token vencido o revocado) cierra la
/// sesión local, para que el router lleve al login, y vuelve a lanzar el error.
Future<T> conSesion<T>(Ref ref, Future<T> Function() accion) async {
  try {
    return await accion();
  } on UnauthorizedFailure {
    await ref.read(sesionControllerProvider.notifier).sesionExpirada();
    rethrow;
  }
}
