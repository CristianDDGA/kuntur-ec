import '../models/reserva.dart';
import 'api_exception.dart';
import 'rest_client.dart';

/// Consume el servicio de Reservas de la API (`/reservas`). Solo clientes: el administrador recibe 403.
class ReservaService {
  const ReservaService(this._client);

  /// Máximo de asientos por reserva (igual que el servidor).
  static const int maxAsientos = 10;
  static const int porPagina = 10;

  final RestClient _client;

  /// `POST /reservas` con los asientos elegidos. El usuario sale del token, nunca del cuerpo.
  /// Si alguno ya lo tomó otra persona responde 409 con `asientosOcupados`.
  Future<Reserva> crear({required int vueloId, required List<String> asientos}) async =>
      _reservaDe(await _client.post('/reservas', body: {'vuelo_id': vueloId, 'asientos': asientos}));

  /// `GET /reservas?pagina=&por_pagina=`: historial del usuario, la más reciente primero.
  Future<PaginaReservas> listar({int pagina = 1}) async => PaginaReservas.fromJson(
        asJsonMap(await _client.get('/reservas', query: {'pagina': '$pagina', 'por_pagina': '$porPagina'})),
      );

  /// `GET /reservas/{id}`. Una reserva ajena responde 404.
  Future<Reserva> obtener(int id) async => Reserva.fromJson(asJsonMap(await _client.get('/reservas/$id')));

  /// `PUT /reservas/{id}`: deja la reserva con exactamente estos asientos (puede cambiar de lugar, ampliar
  /// o reducir). Se envía la `version` leída; si otro la cambió, 409.
  Future<Reserva> modificar({required int id, required List<String> asientos, required int version}) async =>
      _reservaDe(await _client.put('/reservas/$id', body: {'asientos': asientos, 'version': version}));

  /// `DELETE /reservas/{id}`: cancela y devuelve los asientos al vuelo.
  Future<Reserva> cancelar(int id) async => _reservaDe(await _client.delete('/reservas/$id'));

  /// `GET /reservas/{id}/comprobante`: la factura en XML (se muestra en F4).
  Future<String> comprobanteXml(int id) => _client.getXml('/reservas/$id/comprobante');

  Reserva _reservaDe(Object? json) {
    final reserva = asJsonMap(json)['reserva'];
    if (reserva is! JsonMap) throw const InvalidResponseFailure();
    return Reserva.fromJson(reserva);
  }
}
