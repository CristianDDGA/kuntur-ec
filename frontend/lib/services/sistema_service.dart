import '../models/estado_servicio.dart';
import 'rest_client.dart';

/// Consume el servicio de estado de la API.
class SistemaService {
  const SistemaService(this._client);

  final RestClient _client;

  Future<EstadoServicio> consultarEstado() async =>
      EstadoServicio.fromJson(asJsonMap(await _client.get('/health')));
}
