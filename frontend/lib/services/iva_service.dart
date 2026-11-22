import '../models/tarifa_iva.dart';
import '../models/vuelo.dart';
import 'api_exception.dart';
import 'rest_client.dart';

/// Consume el servicio de IVA de la API (`/iva`).
class IvaService {
  const IvaService(this._client);

  final RestClient _client;

  /// `GET /iva`: tarifa vigente e historial.
  Future<ResumenIva> consultar() async => ResumenIva.fromJson(asJsonMap(await _client.get('/iva')));

  /// `POST /iva` (solo administrador). [porcentaje] va como texto ("15" o "12.5") para no perder precisión.
  Future<TarifaIva> cambiar({required String porcentaje, required DateTime vigenteDesde}) async {
    final json = asJsonMap(await _client.post('/iva', body: {
      'porcentaje': porcentaje,
      'vigente_desde': Formatos.fechaIso(vigenteDesde),
    }));
    final tarifa = json['tarifa'];
    if (tarifa is! JsonMap) throw const InvalidResponseFailure();
    return TarifaIva.fromJson(tarifa);
  }
}
