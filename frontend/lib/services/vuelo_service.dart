import '../models/asientos.dart';
import '../models/destino.dart';
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

  /// `GET /vuelos/destinos`: ciudades con vuelos próximos y su tarifa mínima. Es público (portada).
  Future<List<DestinoPopular>> destinos() async {
    final lista = asJsonMap(await _client.get('/vuelos/destinos'))['destinos'];
    if (lista is! List) throw const InvalidResponseFailure();
    return [for (final d in lista) DestinoPopular.fromJson(asJsonMap(d))];
  }

  /// `GET /vuelos/{id}`. Lanza [ServerFailure] con 404 si el vuelo no existe.
  Future<Vuelo> obtener(int id) async =>
      Vuelo.fromJson(asJsonMap(await _client.get('/vuelos/$id')));

  /// `GET /vuelos/{id}/asientos`: mapa de asientos (capacidad y ocupados). Es público.
  Future<MapaAsientos> mapaAsientos(int id) async =>
      MapaAsientos.fromJson(asJsonMap(await _client.get('/vuelos/$id/asientos')));

  /// `POST /vuelos` (solo administrador).
  Future<Vuelo> crear(NuevoVuelo datos) async =>
      _vueloDe(asJsonMap(await _client.post('/vuelos', body: datos.toJson())));

  /// `GET /vuelos/gestion` (solo administrador): todos los vuelos, también cancelados y ya partidos.
  Future<PaginaGestion> gestion(FiltroGestion filtro) async =>
      PaginaGestion.fromJson(asJsonMap(await _client.get('/vuelos/gestion', query: filtro.consulta)));

  /// `PUT /vuelos/{id}` (solo administrador). 409 si otro administrador lo cambió antes.
  Future<Vuelo> editar(int id, EdicionVuelo datos) async =>
      _vueloDe(asJsonMap(await _client.put('/vuelos/$id', body: datos.toJson())));

  /// `POST /vuelos/{id}/cancelacion` (solo administrador). Devuelve el vuelo cancelado y cuántas
  /// reservas se cancelaron con él.
  Future<({Vuelo vuelo, int reservasCanceladas})> cancelar(int id, {required String motivo, required int version}) async {
    final json = asJsonMap(
      await _client.post('/vuelos/$id/cancelacion', body: {'motivo': motivo, 'version': version}),
    );
    final canceladas = json['reservas_canceladas'];
    if (canceladas is! int) throw const InvalidResponseFailure();
    return (vuelo: _vueloDe(json), reservasCanceladas: canceladas);
  }

  static Vuelo _vueloDe(JsonMap json) {
    final vuelo = json['vuelo'];
    if (vuelo is! JsonMap) throw const InvalidResponseFailure();
    return Vuelo.fromJson(vuelo);
  }
}
