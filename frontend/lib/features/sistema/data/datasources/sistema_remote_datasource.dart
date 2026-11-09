import '../../../../core/network/rest_client.dart';
import '../models/estado_servicio_model.dart';

abstract interface class SistemaRemoteDataSource {
  Future<EstadoServicioModel> obtenerEstado();
}

class SistemaRemoteDataSourceImpl implements SistemaRemoteDataSource {
  const SistemaRemoteDataSourceImpl(this._client);

  final RestClient _client;

  @override
  Future<EstadoServicioModel> obtenerEstado() async =>
      EstadoServicioModel.fromJson(asJsonMap(await _client.get('/health')));
}
