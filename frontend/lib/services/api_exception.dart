/// Errores que los servicios entregan a los controladores.
/// La UI solo conoce estos tipos, nunca excepciones de `http`.
sealed class Failure implements Exception {
  const Failure(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// La API respondió con un error controlado: {"error": "...", "mensaje": "..."}.
final class ServerFailure extends Failure {
  const ServerFailure(super.mensaje, {required this.statusCode, this.codigo, this.detalles = const {}});
  final int statusCode;
  final String? codigo;

  /// Datos extra del error (p. ej. `version_actual`, `asientos_ocupados` en un 409).
  final Map<String, dynamic> detalles;

  /// Asientos que ya no estaban libres cuando se intentó reservar (409), o lista vacía.
  List<String> get asientosOcupados {
    final lista = detalles['asientos_ocupados'];
    return lista is List ? lista.whereType<String>().toList() : const [];
  }
}

/// Token ausente, vencido o revocado (HTTP 401).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.mensaje = 'Su sesión ha expirado. Inicie sesión nuevamente.']);
}

/// Sin conexión, timeout o servidor caído.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.mensaje = 'No se pudo conectar con el servidor.']);
}

/// La API respondió con un formato inesperado.
final class InvalidResponseFailure extends Failure {
  const InvalidResponseFailure([super.mensaje = 'El servidor envió una respuesta no válida.']);
}

/// Texto para mostrar al usuario. Los [Failure] ya traen un mensaje en español;
/// cualquier otra excepción se oculta tras un mensaje genérico (sin detalles técnicos).
String mensajeDeError(Object error) =>
    error is Failure ? error.mensaje : 'Ocurrió un error inesperado. Intente nuevamente.';
