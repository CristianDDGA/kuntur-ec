import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_error_mapper.dart';
import 'api_exception.dart';
import 'rest_client.dart';
import 'token_storage.dart';

/// Implementación de [RestClient] con `package:http`.
/// Responsabilidad única: transportar peticiones (cabeceras, JWT, timeout).
/// La traducción de errores se delega a [ApiErrorMapper].
class HttpRestClient implements RestClient {
  HttpRestClient({
    required http.Client httpClient,
    required TokenStorage tokenStorage,
    required String baseUrl,
    ApiErrorMapper errorMapper = const ApiErrorMapper(),
    Duration timeout = AppConfig.requestTimeout,
  })  : _http = httpClient,
        _tokens = tokenStorage,
        _apiBaseUrl = baseUrl,
        _errors = errorMapper,
        _requestTimeout = timeout;

  static const _json = 'application/json';
  static const _xml = 'application/xml';

  final http.Client _http;
  final TokenStorage _tokens;
  final String _apiBaseUrl;
  final ApiErrorMapper _errors;
  final Duration _requestTimeout;

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _sendJson('GET', path, query: query);

  @override
  Future<Object?> post(String path, {Object? body}) => _sendJson('POST', path, body: body);

  @override
  Future<Object?> put(String path, {Object? body}) => _sendJson('PUT', path, body: body);

  @override
  Future<Object?> delete(String path) => _sendJson('DELETE', path);

  @override
  Future<String> getXml(String path) async =>
      (await _send('GET', path, accept: _xml)).body;

  Future<Object?> _sendJson(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final response = await _send(method, path, query: query, body: body, accept: _json);
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const InvalidResponseFailure();
    }
  }

  Future<http.Response> _send(String method, String path,
      {Map<String, String>? query, Object? body, required String accept}) async {
    final token = await _tokens.leer();
    final request = http.Request(method, Uri.parse('$_apiBaseUrl$path').replace(queryParameters: query))
      ..headers['Accept'] = accept;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = _json;
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_requestTimeout));
    } on TimeoutException {
      throw const NetworkFailure('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const NetworkFailure();
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) throw _errors.fromResponse(response.statusCode, response.body);
    return response;
  }
}
