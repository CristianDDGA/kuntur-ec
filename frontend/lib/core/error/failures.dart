/// Errores que la capa de datos entrega al dominio/presentación.
/// La UI solo conoce estos tipos, nunca excepciones de `http`.
sealed class Failure implements Exception {
  const Failure(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// La API respondió con un error controlado: {"error": "...", "mensaje": "..."}.
final class ServerFailure extends Failure {
  const ServerFailure(super.mensaje, {required this.statusCode, this.codigo});
  final int statusCode;
  final String? codigo;
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
