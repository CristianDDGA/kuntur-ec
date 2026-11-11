import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/reserva_service.dart';

import '../helpers/fakes.dart';

void main() {
  test('crear envía vuelo y asientos (nunca el usuario) y devuelve la reserva', () async {
    final api = RouteFakeRestClient({'POST /reservas': {'mensaje': 'ok', 'reserva': reservaJson()}});
    final r = await ReservaService(api).crear(vueloId: 3, asientos: ['1A', '1B']);
    expect(api.llamada('POST', '/reservas').cuerpo, {'vuelo_id': 3, 'asientos': ['1A', '1B']});
    expect(r.id, 58);
    expect(r.asientos, ['1A', '1B']);
  });

  test('listar pide la página y el tamaño', () async {
    final api = RouteFakeRestClient({'GET /reservas': paginaDeReservas(total: 25, pagina: 2)});
    final p = await ReservaService(api).listar(pagina: 2);
    expect(api.llamada('GET', '/reservas').consulta, {'pagina': '2', 'por_pagina': '10'});
    expect(p.reservas, hasLength(10));
  });

  test('modificar envía los asientos finales y la versión leída', () async {
    final api = RouteFakeRestClient({'PUT /reservas/58': {'mensaje': 'ok', 'reserva': reservaJson(cantidad: 3, version: 2)}});
    final r = await ReservaService(api).modificar(id: 58, asientos: ['1A', '1B', '1C'], version: 1);
    expect(api.llamada('PUT', '/reservas/58').cuerpo, {'asientos': ['1A', '1B', '1C'], 'version': 1});
    expect((r.cantidad, r.version), (3, 2));
  });

  test('cancelar devuelve la reserva cancelada', () async {
    final api = RouteFakeRestClient({'DELETE /reservas/58': {'mensaje': 'ok', 'reserva': reservaJson(estado: 'cancelada')}});
    expect((await ReservaService(api).cancelar(58)).cancelada, isTrue);
  });

  test('el 403 del administrador y el 409 de versión llegan como ServerFailure', () async {
    final api = RouteFakeRestClient({
      'POST /reservas': const ServerFailure('No tiene permiso para realizar esta acción.', statusCode: 403),
      'PUT /reservas/58': const ServerFailure('Ya actualizaron este registro.', statusCode: 409),
    });
    final s = ReservaService(api);
    expect(s.crear(vueloId: 3, asientos: ['1A']), throwsA(isA<ServerFailure>().having((e) => e.statusCode, 'status', 403)));
    expect(s.modificar(id: 58, asientos: ['1A'], version: 1), throwsA(isA<ServerFailure>().having((e) => e.statusCode, 'status', 409)));
  });

  test('una respuesta sin "reserva" es InvalidResponseFailure', () async {
    final api = RouteFakeRestClient({'POST /reservas': {'mensaje': 'ok'}});
    expect(ReservaService(api).crear(vueloId: 3, asientos: ['1A']), throwsA(isA<InvalidResponseFailure>()));
  });

  test('el comprobante se pide como XML', () async {
    final api = RouteFakeRestClient({'GET /reservas/58/comprobante': '<factura/>'});
    expect(await ReservaService(api).comprobanteXml(58), '<factura/>');
  });
}
