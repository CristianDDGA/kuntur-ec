import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vuelos_app/core/error/failures.dart';
import 'package:vuelos_app/core/network/http_rest_client.dart';

import '../../helpers/fakes.dart';

const _base = 'http://api.test/api';

HttpRestClient _client(MockClientHandler handler, {String? token}) => HttpRestClient(
      httpClient: MockClient(handler),
      tokenStorage: InMemoryTokenStorage(token),
      baseUrl: _base,
    );

void main() {
  test('GET envía JWT y no envía Content-Type', () async {
    late http.Request enviado;
    final client = _client((req) async {
      enviado = req;
      return http.Response('{"ok":true}', 200);
    }, token: 'abc');

    final data = await client.get('/vuelos', query: {'origen': 'Quito'});

    expect(data, {'ok': true});
    expect(enviado.url.toString(), '$_base/vuelos?origen=Quito');
    expect(enviado.headers['Authorization'], 'Bearer abc');
    expect(enviado.headers['Accept'], 'application/json');
    expect(enviado.headers.containsKey('Content-Type'), isFalse);
  });

  test('POST serializa el cuerpo como JSON', () async {
    late http.Request enviado;
    final client = _client((req) async {
      enviado = req;
      return http.Response('', 201);
    });

    final data = await client.post('/reservas', body: {'vuelo_id': 10, 'cantidad': 2});

    expect(data, isNull);
    expect(enviado.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(enviado.body), {'vuelo_id': 10, 'cantidad': 2});
    expect(enviado.headers.containsKey('Authorization'), isFalse);
  });

  test('getXml solicita XML y devuelve el texto', () async {
    final client = _client((req) async {
      expect(req.headers['Accept'], 'application/xml');
      return http.Response('<factura/>', 200);
    });
    expect(await client.getXml('/reservas/1/comprobante'), '<factura/>');
  });

  test('respuesta de error se convierte en Failure', () async {
    final client = _client(
        (_) async => http.Response('{"error":"no_encontrado","mensaje":"No existe"}', 404));
    expect(client.get('/vuelos/99'),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 404)));
  });

  test('falla de red se convierte en NetworkFailure', () async {
    final client = _client((_) async => throw http.ClientException('sin red'));
    expect(client.get('/health'), throwsA(isA<NetworkFailure>()));
  });

  test('JSON inválido se convierte en InvalidResponseFailure', () async {
    final client = _client((_) async => http.Response('no-json', 200));
    expect(client.get('/health'), throwsA(isA<InvalidResponseFailure>()));
  });
}
