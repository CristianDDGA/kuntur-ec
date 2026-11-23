import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/vuelo.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/vuelo_service.dart';

import '../helpers/fakes.dart';

final _paginaGestion = <String, Object?>{
  'total': 1,
  'pagina': 1,
  'por_pagina': 10,
  'total_paginas': 1,
  'vuelos': [
    {...vueloQuitoGuayaquil, 'ya_partio': false, 'asientos_vendidos': 38},
  ],
};

void main() {
  test('gestion pide el filtro elegido y lee si cada vuelo ya partió', () async {
    final api = RouteFakeRestClient({'GET /vuelos/gestion': _paginaGestion});
    final pagina = await VueloService(api).gestion(const FiltroGestion(estado: EstadoVuelo.programado, pagina: 3));
    expect(pagina.vuelos.single.vuelo.codigo, 'KT101');
    expect(pagina.vuelos.single.yaPartio, isFalse);
    expect(api.llamada('GET', '/vuelos/gestion').consulta, {'estado': 'programado', 'pagina': '3', 'por_pagina': '10'});
  });

  test('editar hace PUT con la versión y devuelve el vuelo actualizado', () async {
    final api = RouteFakeRestClient({
      'PUT /vuelos/3': {'mensaje': 'Vuelo actualizado correctamente.', 'vuelo': {...vueloQuitoGuayaquil, 'version': 2}},
    });
    final vuelo = await VueloService(api).editar(
      3,
      EdicionVuelo(
        origen: 'Quito',
        destino: 'Guayaquil',
        fecha: DateTime(2026, 12, 1),
        horaSalida: const Duration(hours: 8),
        horaLlegada: const Duration(hours: 8, minutes: 55),
        precio: '80.00',
        version: 1,
      ),
    );
    expect(vuelo.version, 2);
    final cuerpo = api.llamada('PUT', '/vuelos/3').cuerpo as Map;
    expect(cuerpo['version'], 1);
    expect(cuerpo['precio'], '80.00');
    expect(cuerpo.containsKey('avion_id'), isFalse); // el avión no cambió: no se envía
  });

  test('editar propaga el 409 con la versión actual', () async {
    final api = RouteFakeRestClient({
      'PUT /vuelos/3': const ServerFailure('Ya actualizaron este vuelo.', statusCode: 409, detalles: {'version_actual': 2}),
    });
    final datos = EdicionVuelo(
      origen: 'Quito',
      destino: 'Guayaquil',
      fecha: DateTime(2026, 12, 1),
      horaSalida: Duration.zero,
      horaLlegada: const Duration(hours: 1),
      precio: '1',
      version: 1,
    );
    expect(VueloService(api).editar(3, datos), throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'status', 409)));
  });

  test('cancelar envía motivo y versión y devuelve cuántas reservas cayeron', () async {
    final api = RouteFakeRestClient({
      'POST /vuelos/3/cancelacion': {
        'mensaje': 'Vuelo cancelado correctamente.',
        'vuelo': {...vueloQuitoGuayaquil, 'estado': 'cancelado', 'motivo_cancelacion': 'Cierre del aeropuerto'},
        'reservas_canceladas': 4,
      },
    });
    final r = await VueloService(api).cancelar(3, motivo: 'Cierre del aeropuerto', version: 1);
    expect(r.reservasCanceladas, 4);
    expect(r.vuelo.cancelado, isTrue);
    expect(api.llamada('POST', '/vuelos/3/cancelacion').cuerpo, {'motivo': 'Cierre del aeropuerto', 'version': 1});
  });

  test('cancelar sin "reservas_canceladas" es InvalidResponseFailure', () async {
    final api = RouteFakeRestClient({
      'POST /vuelos/3/cancelacion': {'vuelo': vueloQuitoGuayaquil},
    });
    expect(
      VueloService(api).cancelar(3, motivo: 'Cierre del aeropuerto', version: 1),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });
}
