import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../error/failures.dart';
import '../storage/token_storage.dart';

/// Cliente HTTP único para consumir los servicios REST.
/// - Agrega `Authorization: Bearer <jwt>` si hay sesión.
/// - Convierte las respuestas de error de la API en [Failure].
class ApiClient {
  ApiClient({required http.Client httpClient, required TokenStorage tokenStorage, String? baseUrl})
      : _http = httpClient,
        _tokens = tokenStorage,
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final TokenStorage _tokens;
  final String _baseUrl;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Descarga el cuerpo como texto plano (p. ej. el comprobante XML).
  Future<String> getXml(String path) async {
    final response = await _request('GET', path, accept: 'application/xml');
    return response.body;
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final response = await _request(method, path, query: query, body: body);
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<http.Response> _request(String method, String path,
      {Map<String, String>? query,
      Object? body,
      String accept = 'application/json'}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final token = await _tokens.leer();
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': accept,
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const NetworkFailure('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const NetworkFailure();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return response;
    throw _toFailure(response);
  }

  Failure _toFailure(http.Response response) {
    String mensaje = 'Error inesperado (${response.statusCode}).';
    String? codigo;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      mensaje = data['mensaje'] as String? ?? mensaje;
      codigo = data['error'] as String?;
    } catch (_) {/* cuerpo no JSON: se usa el mensaje genérico */}
    if (response.statusCode == 401) return UnauthorizedFailure(mensaje);
    return ServerFailure(mensaje, statusCode: response.statusCode, codigo: codigo);
  }
}
