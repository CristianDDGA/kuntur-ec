import '../../domain/entities/estado_servicio.dart';
import '../../domain/repositories/sistema_repository.dart';
import '../datasources/sistema_remote_datasource.dart';

class SistemaRepositoryImpl implements SistemaRepository {
  const SistemaRepositoryImpl(this._remote);

  final SistemaRemoteDataSource _remote;

  @override
  Future<EstadoServicio> consultarEstado() => _remote.obtenerEstado();
}
