import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/sistema_service.dart';

import '../helpers/fakes.dart';

void main() {
  test('convierte la respuesta de /health en EstadoServicio', () async {
    final client = FakeRestClient(respuesta: healthOk);

    final estado = await SistemaService(client).consultarEstado();

    expect(client.rutasSolicitadas, ['/health']);
    expect(estado.servicio, 'kuntur-ec-api');
    expect(estado.disponible, isTrue);
    expect(estado.hora.isUtc, isTrue);
  });

  test('respuesta incompleta lanza InvalidResponseFailure', () {
    final service = SistemaService(FakeRestClient(respuesta: {'estado': 'ok'}));
    expect(service.consultarEstado(), throwsA(isA<InvalidResponseFailure>()));
  });

  test('propaga el Failure del cliente', () {
    final service = SistemaService(FakeRestClient(error: const NetworkFailure()));
    expect(service.consultarEstado(), throwsA(isA<NetworkFailure>()));
  });
}
