import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/reserva.dart';
import 'package:vuelos_app/models/validadores_vuelo.dart';
import 'package:vuelos_app/models/vuelo.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('Vuelo con estado', () {
    test('sin estado (respuesta anterior) se toma como programado', () {
      final v = Vuelo.fromJson(vueloQuitoGuayaquil);
      expect(v.estado, EstadoVuelo.programado);
      expect(v.cancelado, isFalse);
      expect(v.asientosVendidos, 38);
      expect(v.tieneReservas, isTrue);
    });

    test('lee el estado, el motivo y el avión', () {
      final v = Vuelo.fromJson({
        ...vueloQuitoGuayaquil,
        'estado': 'cancelado',
        'motivo_cancelacion': 'Cierre del aeropuerto',
        'avion_id': 7,
      });
      expect(v.cancelado, isTrue);
      expect(v.motivoCancelacion, 'Cierre del aeropuerto');
      expect(v.avionId, 7);
    });

    test('un estado desconocido o tipos inválidos son InvalidResponseFailure', () {
      for (final malo in [
        {...vueloQuitoGuayaquil, 'estado': 'borrado'},
        {...vueloQuitoGuayaquil, 'motivo_cancelacion': 5},
        {...vueloQuitoGuayaquil, 'avion_id': '7'},
      ]) {
        expect(() => Vuelo.fromJson(malo), throwsA(isA<InvalidResponseFailure>()));
      }
    });

    test('el resumen del vuelo en una reserva también trae el estado', () {
      final r = ResumenVuelo.fromJson({
        ...vueloQuitoGuayaquil,
        'estado': 'cancelado',
        'motivo_cancelacion': 'Mal clima en destino',
      });
      expect(r.cancelado, isTrue);
      expect(r.motivoCancelacion, 'Mal clima en destino');
    });
  });

  test('EdicionVuelo envía la versión y el avión solo si cambia', () {
    final base = EdicionVuelo(
      origen: 'Quito',
      destino: 'Guayaquil',
      fecha: DateTime(2026, 12, 1),
      horaSalida: const Duration(hours: 7, minutes: 5),
      horaLlegada: const Duration(hours: 8),
      precio: '80.00',
      version: 4,
    );
    expect(base.toJson(), {
      'origen': 'Quito',
      'destino': 'Guayaquil',
      'fecha': '2026-12-01',
      'hora_salida': '07:05',
      'hora_llegada': '08:00',
      'precio': '80.00',
      'version': 4,
    });
    final conAvion = EdicionVuelo(
      origen: 'Quito',
      destino: 'Guayaquil',
      fecha: DateTime(2026, 12, 1),
      horaSalida: Duration.zero,
      horaLlegada: const Duration(hours: 1),
      precio: '80',
      version: 4,
      avionId: 9,
    );
    expect(conAvion.toJson()['avion_id'], 9);
  });

  test('PaginaGestion exige ya_partio en cada vuelo', () {
    final ok = PaginaGestion.fromJson({
      'total': 2,
      'pagina': 1,
      'por_pagina': 10,
      'total_paginas': 1,
      'vuelos': [
        {...vueloQuitoGuayaquil, 'ya_partio': false},
        {...vueloCuencaQuito, 'ya_partio': true, 'estado': 'programado'},
      ],
    });
    expect(ok.vuelos.map((v) => v.gestionable), [true, false]);
    expect(
      () => PaginaGestion.fromJson({...respuestaVuelos}),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });

  test('un vuelo cancelado no es gestionable aunque no haya partido', () {
    final v = Vuelo.fromJson({...vueloQuitoGuayaquil, 'estado': 'cancelado', 'motivo_cancelacion': 'Clima severo'});
    expect(VueloGestionado(vuelo: v, yaPartio: false).gestionable, isFalse);
  });

  test('FiltroGestion envía el estado solo si se eligió', () {
    expect(const FiltroGestion().consulta, {'pagina': '1', 'por_pagina': '10'});
    expect(const FiltroGestion(estado: EstadoVuelo.cancelado, pagina: 2).consulta,
        {'estado': 'cancelado', 'pagina': '2', 'por_pagina': '10'});
  });

  group('motivo de cancelación (igual que el servidor)', () {
    test('acepta un motivo claro', () {
      expect(ValidadoresVuelo.motivoCancelacion('Cierre del aeropuerto por ceniza'), isNull);
    });

    test('rechaza vacío, corto, sin letras, largo o con caracteres de control', () {
      expect(ValidadoresVuelo.motivoCancelacion('   '), contains('Escriba'));
      expect(ValidadoresVuelo.motivoCancelacion('Clima'), contains('10 letras'));
      expect(ValidadoresVuelo.motivoCancelacion('1234567890 !!'), contains('10 letras'));
      expect(ValidadoresVuelo.motivoCancelacion('a' * 201), contains('200'));
      expect(ValidadoresVuelo.motivoCancelacion('Mal clima\u0000 en destino'), contains('no permitidos'));
    });

    test('al escribir, los saltos de línea se vuelven espacios y el largo se corta en 200', () {
      var texto = 'Mal\nclima ${'x' * 300}';
      for (final f in ValidadoresVuelo.entradaMotivo) {
        texto = f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texto)).text;
      }
      expect(texto, isNot(contains('\n')));
      expect(texto.startsWith('Mal clima'), isTrue);
      expect(texto.length, ValidadoresVuelo.motivoMax);
    });
  });
}
