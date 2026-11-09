import '../entities/estado_servicio.dart';

abstract interface class SistemaRepository {
  /// Lanza un `Failure` si el servicio no responde correctamente.
  Future<EstadoServicio> consultarEstado();
}
