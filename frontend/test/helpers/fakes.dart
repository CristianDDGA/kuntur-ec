import 'package:vuelos_app/services/rest_client.dart';
import 'package:vuelos_app/services/token_storage.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);
  String? _token;

  @override
  Future<String?> leer() async => _token;

  @override
  Future<void> guardar(String token) async => _token = token;

  @override
  Future<void> eliminar() async => _token = null;
}

/// RestClient programable: devuelve [respuesta] o lanza [error] en cada llamada.
class FakeRestClient implements RestClient {
  FakeRestClient({this.respuesta, this.error});

  final Object? respuesta;
  final Object? error;
  final List<String> rutasSolicitadas = [];

  Future<T> _responder<T>(String path, T valor) async {
    rutasSolicitadas.add(path);
    if (error != null) throw error!;
    return valor;
  }

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) => _responder(path, respuesta);

  @override
  Future<Object?> post(String path, {Object? body}) => _responder(path, respuesta);

  @override
  Future<Object?> put(String path, {Object? body}) => _responder(path, respuesta);

  @override
  Future<Object?> delete(String path) => _responder(path, respuesta);

  @override
  Future<String> getXml(String path) => _responder(path, respuesta?.toString() ?? '');
}

const healthOk = {
  'estado': 'ok',
  'servicio': 'kuntur-ec-api',
  'hora': '2026-11-09T14:41:11+00:00',
};
