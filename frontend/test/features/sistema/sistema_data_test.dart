import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/core/error/failures.dart';
import 'package:vuelos_app/features/sistema/data/datasources/sistema_remote_datasource.dart';
import 'package:vuelos_app/features/sistema/data/repositories/sistema_repository_impl.dart';

import '../../helpers/fakes.dart';

void main() {
  SistemaRepositoryImpl repositorio(FakeRestClient client) =>
      SistemaRepositoryImpl(SistemaRemoteDataSourceImpl(client));

  test('convierte la respuesta de /health en EstadoServicio', () async {
    final client = FakeRestClient(respuesta: {
      'estado': 'ok',
      'servicio': 'kuntur-ec-api',
      'hora': '2026-11-09T14:41:11+00:00',
    });

    final estado = await repositorio(client).consultarEstado();

    expect(client.rutasSolicitadas, ['/health']);
    expect(estado.servicio, 'kuntur-ec-api');
    expect(estado.disponible, isTrue);
    expect(estado.hora.isUtc, isTrue);
  });

  test('respuesta incompleta lanza InvalidResponseFailure', () {
    final client = FakeRestClient(respuesta: {'estado': 'ok'});
    expect(repositorio(client).consultarEstado(), throwsA(isA<InvalidResponseFailure>()));
  });

  test('propaga el Failure del cliente', () {
    final client = FakeRestClient(error: const NetworkFailure());
    expect(repositorio(client).consultarEstado(), throwsA(isA<NetworkFailure>()));
  });
}
