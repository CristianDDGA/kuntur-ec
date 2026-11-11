import '../models/vuelo.dart';
import 'api_exception.dart';
import 'rest_client.dart';

/// Consume el servicio de Vuelos de la API (`/vuelos`).
class VueloService {
  const VueloService(this._client);

  final RestClient _client;

  /// `GET /vuelos?origen=&destino=&fecha=&pagina=&por_pagina=`: una página de vuelos que aún no parten.
  Future<PaginaVuelos> buscar(FiltroVuelos filtro) async =>
      PaginaVuelos.fromJson(asJsonMap(await _client.get('/vuelos', query: filtro.consulta)));

  /// `GET /vuelos/{id}`. Lanza [ServerFailure] con 404 si el vuelo no existe.
  Future<Vuelo> obtener(int id) async =>
      Vuelo.fromJson(asJsonMap(await _client.get('/vuelos/$id')));

  /// `POST /vuelos` (solo administrador).
  Future<Vuelo> crear(NuevoVuelo datos) async {
    final json = asJsonMap(await _client.post('/vuelos', body: datos.toJson()));
    final vuelo = json['vuelo'];
    if (vuelo is! JsonMap) throw const InvalidResponseFailure();
    return Vuelo.fromJson(vuelo);
  }
}
