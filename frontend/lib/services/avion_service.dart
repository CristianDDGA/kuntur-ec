import '../models/avion.dart';
import 'api_exception.dart';
import 'rest_client.dart';

/// Consume el servicio de Aviones de la API (`/aviones`, solo administrador).
class AvionService {
  const AvionService(this._client);

  final RestClient _client;

  /// `GET /aviones`: aviones registrados, por matrícula.
  Future<List<Avion>> listar() async {
    final json = asJsonMap(await _client.get('/aviones'));
    final aviones = json['aviones'];
    if (aviones is! List) throw const InvalidResponseFailure();
    return asJsonList(aviones).map(Avion.fromJson).toList();
  }

  /// `POST /aviones/importacion/validar`: revisa el CSV sin guardar nada.
  /// El cuerpo se envía como texto (`text/csv`): el cliente HTTP lo distingue del JSON por ser un [String].
  Future<ResumenCsv> validar(String csv) async =>
      ResumenCsv.fromJson(asJsonMap(await _client.post('/aviones/importacion/validar', body: csv)));

  /// `POST /aviones/importacion`: guarda los aviones del CSV (todo o nada).
  Future<ResultadoImportacion> importar(String csv) async =>
      ResultadoImportacion.fromJson(asJsonMap(await _client.post('/aviones/importacion', body: csv)));
}
