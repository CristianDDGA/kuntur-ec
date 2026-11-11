import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/vuelo.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/vuelo_service.dart';

import '../helpers/fakes.dart';

void main() {
  test('buscar devuelve los vuelos y envía solo los filtros usados', () async {
    final api = RouteFakeRestClient({'GET /vuelos': respuestaVuelos});
    final pagina = await VueloService(api).buscar(FiltroVuelos(origen: 'Quito', fecha: DateTime(2026, 12, 1), pagina: 2));

    expect(pagina.vuelos.map((v) => v.codigo), ['KT101', 'KT202']);
    expect(pagina.total, 2);
    expect(api.llamada('GET', '/vuelos').consulta, {
      'origen': 'Quito',
      'fecha': '2026-12-01',
      'pagina': '2',
      'por_pagina': '10',
    });
  });

  test('buscar sin resultados devuelve lista vacía', () async {
    final api = RouteFakeRestClient({'GET /vuelos': sinVuelos});
    expect((await VueloService(api).buscar(const FiltroVuelos())).vuelos, isEmpty);
  });

  test('buscar con una respuesta sin "vuelos" es InvalidResponseFailure', () async {
    final api = RouteFakeRestClient({'GET /vuelos': {'total': 0, 'vuelos': <Object>[]}});
    expect(VueloService(api).buscar(const FiltroVuelos()), throwsA(isA<InvalidResponseFailure>()));
  });

  test('obtener lee el detalle y propaga el 404', () async {
    final ok = RouteFakeRestClient({'GET /vuelos/3': vueloQuitoGuayaquil});
    expect((await VueloService(ok).obtener(3)).destino, 'Guayaquil');

    final noExiste = RouteFakeRestClient({
      'GET /vuelos/99': const ServerFailure('El vuelo solicitado no existe.', statusCode: 404),
    });
    expect(VueloService(noExiste).obtener(99), throwsA(isA<ServerFailure>()));
  });

  test('crear envía el cuerpo y devuelve el vuelo creado', () async {
    final api = RouteFakeRestClient({
      'POST /vuelos': {'mensaje': 'Vuelo creado correctamente.', 'vuelo': vueloQuitoGuayaquil},
    });
    final vuelo = await VueloService(api).crear(NuevoVuelo(
      origen: 'Quito',
      destino: 'Guayaquil',
      fecha: DateTime(2026, 12, 1),
      horaSalida: const Duration(hours: 8),
      horaLlegada: const Duration(hours: 8, minutes: 55),
      precio: '75.50',
      capacidad: 80,
    ));
    expect(vuelo.id, 3);
    expect((api.llamada('POST', '/vuelos').cuerpo as Map)['hora_llegada'], '08:55');
  });
}
