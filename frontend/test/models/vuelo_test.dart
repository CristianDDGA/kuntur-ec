import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/vuelo.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('Vuelo.fromJson', () {
    test('lee el contrato de la API', () {
      final v = Vuelo.fromJson(vueloQuitoGuayaquil);
      expect(v.id, 3);
      expect(v.codigo, 'KT101');
      expect(v.fecha, DateTime(2026, 12, 1));
      expect(v.horaSalida, const Duration(hours: 8));
      expect(v.horaLlegada, const Duration(hours: 8, minutes: 55));
      expect(v.precioCentavos, 7550);
      expect(v.version, 1);
    });

    test('el precio se maneja en centavos exactos', () {
      Vuelo con(String precio) => Vuelo.fromJson({...vueloQuitoGuayaquil, 'precio': precio});
      expect(con('0.10').precioCentavos, 10);
      expect(con('204.7').precioCentavos, 20470);
      expect(con('60').precioCentavos, 6000);
      expect(con('9999.99').precioCentavos, 999999);
    });

    test('la duración cruza la medianoche', () {
      expect(Vuelo.fromJson(vueloQuitoGuayaquil).duracion, const Duration(minutes: 55));
      expect(Vuelo.fromJson(vueloCuencaQuito).duracion, const Duration(minutes: 55));
    });

    test('disponibilidad: agotado y pocos asientos', () {
      Vuelo con(int n) => Vuelo.fromJson({...vueloQuitoGuayaquil, 'asientos_disponibles': n});
      expect(con(0).agotado, isTrue);
      expect(con(1).pocosAsientos, isTrue);
      expect(con(5).pocosAsientos, isTrue);
      expect(con(6).pocosAsientos, isFalse);
      expect(con(0).pocosAsientos, isFalse);
    });

    test('una respuesta incompleta o mal formada es InvalidResponseFailure', () {
      for (final malo in <Map<String, dynamic>>[
        {...vueloQuitoGuayaquil, 'id': '3'},
        {...vueloQuitoGuayaquil, 'fecha': '01/12/2026'},
        {...vueloQuitoGuayaquil, 'hora_salida': '8am'},
        {...vueloQuitoGuayaquil, 'precio': 'gratis'},
        {...vueloQuitoGuayaquil, 'precio': null},
        {...vueloQuitoGuayaquil}..remove('version'),
      ]) {
        expect(() => Vuelo.fromJson(malo), throwsA(isA<InvalidResponseFailure>()), reason: '$malo');
      }
    });
  });

  group('FiltroVuelos', () {
    test('solo envía los filtros usados', () {
      expect(const FiltroVuelos().consulta, {'pagina': '1', 'por_pagina': '10'});
      expect(const FiltroVuelos().vacio, isTrue);
      final f = FiltroVuelos(origen: 'Quito', fecha: DateTime(2026, 12, 5));
      expect(f.consulta, {'origen': 'Quito', 'fecha': '2026-12-05', 'pagina': '1', 'por_pagina': '10'});
      expect(f.vacio, isFalse);
      expect(f.conPagina(3).consulta['pagina'], '3');
      expect(f.conPagina(3).origen, 'Quito'); // cambiar de página conserva los filtros
    });

    test('es comparable por valor', () {
      expect(const FiltroVuelos(origen: 'Quito'), const FiltroVuelos(origen: 'Quito'));
      expect(const FiltroVuelos(origen: 'Quito'), isNot(const FiltroVuelos(origen: 'Cuenca')));
    });
  });

  group('Formatos', () {
    test('fecha, hora, duración y dinero', () {
      expect(Formatos.fecha(DateTime(2026, 12, 1)), 'mar 1 dic 2026');
      expect(Formatos.fechaIso(DateTime(2026, 3, 9)), '2026-03-09');
      expect(Formatos.hora(const Duration(hours: 8, minutes: 5)), '08:05');
      expect(Formatos.duracion(const Duration(minutes: 45)), '45 min');
      expect(Formatos.duracion(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
      expect(Formatos.dinero(7550), r'$75.50');
      expect(Formatos.dinero(5), r'$0.05');
    });
  });

  test('NuevoVuelo arma el cuerpo que espera la API', () {
    final cuerpo = NuevoVuelo(
      origen: 'Quito',
      destino: 'Esmeraldas',
      fecha: DateTime(2026, 12, 28),
      horaSalida: const Duration(hours: 8),
      horaLlegada: const Duration(hours: 8, minutes: 45),
      precio: '75.50',
      capacidad: 80,
    ).toJson();
    expect(cuerpo, {
      'origen': 'Quito',
      'destino': 'Esmeraldas',
      'fecha': '2026-12-28',
      'hora_salida': '08:00',
      'hora_llegada': '08:45',
      'precio': '75.50',
      'capacidad': 80,
    });
  });
}
