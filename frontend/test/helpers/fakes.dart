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

/// Una llamada registrada por [RouteFakeRestClient].
class Llamada {
  const Llamada(this.metodo, this.ruta, this.cuerpo);
  final String metodo;
  final String ruta;
  final Object? cuerpo;

  @override
  String toString() => '$metodo $ruta';
}

/// RestClient que responde según "METODO /ruta". Cada valor puede ser el JSON de la
/// respuesta, una excepción (se lanza) o una función `(cuerpo) => respuesta`.
class RouteFakeRestClient implements RestClient {
  RouteFakeRestClient(this.rutas);

  final Map<String, Object?> rutas;
  final List<Llamada> llamadas = [];

  Future<Object?> _atender(String metodo, String path, Object? body) async {
    llamadas.add(Llamada(metodo, path, body));
    final clave = '$metodo $path';
    if (!rutas.containsKey(clave)) throw StateError('Ruta sin definir en el fake: $clave');
    final respuesta = rutas[clave];
    if (respuesta is Exception || respuesta is Error) throw respuesta!;
    if (respuesta is Object? Function(Object?)) return respuesta(body);
    return respuesta;
  }

  List<String> get rutasSolicitadas => llamadas.map((l) => l.toString()).toList();

  Llamada llamada(String metodo, String ruta) =>
      llamadas.firstWhere((l) => l.metodo == metodo && l.ruta == ruta);

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) => _atender('GET', path, null);

  @override
  Future<Object?> post(String path, {Object? body}) => _atender('POST', path, body);

  @override
  Future<Object?> put(String path, {Object? body}) => _atender('PUT', path, body);

  @override
  Future<Object?> delete(String path) => _atender('DELETE', path, null);

  @override
  Future<String> getXml(String path) async => '${await _atender('GET', path, null)}';
}

const healthOk = {
  'estado': 'ok',
  'servicio': 'kuntur-ec-api',
  'hora': '2026-11-09T14:41:11+00:00',
};

const usuarioAna = {
  'id': 7,
  'nombre': 'Ana Torres',
  'correo': 'ana@correo.com',
  'rol': 'cliente',
  'fecha_registro': '2026-11-10T15:04:04+00:00',
};

const respuestaLogin = {
  'token': 'jwt-de-prueba',
  'tipo': 'Bearer',
  'expira': '2026-11-10T16:04:04+00:00',
  'usuario': usuarioAna,
};
