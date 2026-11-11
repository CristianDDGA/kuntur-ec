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
  const Llamada(this.metodo, this.ruta, this.cuerpo, [this.consulta]);
  final String metodo;
  final String ruta;
  final Object? cuerpo;

  /// Parámetros de la URL (`?origen=...`) de un GET.
  final Map<String, String>? consulta;

  @override
  String toString() => '$metodo $ruta';
}

/// RestClient que responde según "METODO /ruta". Cada valor puede ser el JSON de la
/// respuesta, una excepción (se lanza) o una función `(cuerpo) => respuesta`.
class RouteFakeRestClient implements RestClient {
  RouteFakeRestClient(this.rutas);

  final Map<String, Object?> rutas;
  final List<Llamada> llamadas = [];

  Future<Object?> _atender(String metodo, String path, Object? body, [Map<String, String>? consulta]) async {
    llamadas.add(Llamada(metodo, path, body, consulta));
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
  Future<Object?> get(String path, {Map<String, String>? query}) => _atender('GET', path, null, query);

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

const usuarioAdmin = {
  'id': 1,
  'nombre': 'Administrador Kuntur',
  'correo': 'admin@kuntur.ec',
  'rol': 'admin',
  'fecha_registro': '2026-11-01T10:00:00+00:00',
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

const vueloQuitoGuayaquil = {
  'id': 3,
  'codigo': 'KT101',
  'origen': 'Quito',
  'destino': 'Guayaquil',
  'fecha': '2026-12-01',
  'hora_salida': '08:00:00',
  'hora_llegada': '08:55:00',
  'precio': '75.50',
  'capacidad': 80,
  'asientos_disponibles': 42,
  'version': 1,
};

const vueloCuencaQuito = {
  'id': 4,
  'codigo': 'KT202',
  'origen': 'Cuenca',
  'destino': 'Quito',
  'fecha': '2026-12-02',
  'hora_salida': '23:30:00',
  'hora_llegada': '00:25:00',
  'precio': '60.00',
  'capacidad': 50,
  'asientos_disponibles': 3,
  'version': 2,
};

const respuestaVuelos = {
  'total': 2,
  'pagina': 1,
  'por_pagina': 10,
  'total_paginas': 1,
  'vuelos': [vueloQuitoGuayaquil, vueloCuencaQuito],
};

const sinVuelos = {'total': 0, 'pagina': 1, 'por_pagina': 10, 'total_paginas': 1, 'vuelos': <Object>[]};

/// Respuesta de una búsqueda con [total] vuelos en total, mostrando la página [pagina].
Map<String, Object?> paginaDeVuelos({required int total, required int pagina, int porPagina = 10}) {
  final paginas = total == 0 ? 1 : (total + porPagina - 1) ~/ porPagina;
  final desde = (pagina - 1) * porPagina;
  final cuantos = (total - desde).clamp(0, porPagina);
  return {
    'total': total,
    'pagina': pagina,
    'por_pagina': porPagina,
    'total_paginas': paginas,
    'vuelos': [
      for (var i = 0; i < cuantos; i++) {...vueloQuitoGuayaquil, 'id': desde + i + 1, 'codigo': 'KT${100 + desde + i + 1}'},
    ],
  };
}

const tarifaVigente = {
  'id': 2,
  'porcentaje': '15.00',
  'vigente_desde': '2024-04-01',
  'vigente_hasta': null,
  'estado': 'vigente',
};

const tarifaAnterior = {
  'id': 1,
  'porcentaje': '12.00',
  'vigente_desde': '2000-01-01',
  'vigente_hasta': '2024-04-01',
  'estado': 'anterior',
};

const respuestaIva = {
  'vigente': tarifaVigente,
  'tarifas': [tarifaVigente, tarifaAnterior],
};
