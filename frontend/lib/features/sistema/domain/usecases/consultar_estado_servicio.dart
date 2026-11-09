import '../entities/estado_servicio.dart';
import '../repositories/sistema_repository.dart';

class ConsultarEstadoServicio {
  const ConsultarEstadoServicio(this._repository);

  final SistemaRepository _repository;

  Future<EstadoServicio> call() => _repository.consultarEstado();
}
