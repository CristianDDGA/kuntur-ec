import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/reserva.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('Reserva.fromJson', () {
    test('lee el contrato de la API con los montos en centavos', () {
      final r = Reserva.fromJson(reservaJson());
      expect(r.id, 58);
      expect(r.cantidad, 2);
      expect(r.subtotalCentavos, 17800);
      expect(r.ivaCentavos, 2670);
      expect(r.totalCentavos, 20470);
      expect(r.ivaPorcentaje, '15.00');
      expect(r.estado, EstadoReserva.confirmada);
      expect(r.version, 1);
      expect(r.vuelo.codigo, 'KT101');
      expect(r.vuelo.fecha, DateTime(2030, 12, 1));
      expect(r.numero, 'KEC-00000058');
    });

    test('una respuesta incompleta o mal formada es InvalidResponseFailure', () {
      for (final mala in <Map<String, Object?>>[
        {...reservaJson(), 'id': '58'},
        {...reservaJson(), 'total': 'mucho'},
        {...reservaJson(), 'total': null},
        {...reservaJson(), 'estado': 'rara'},
        {...reservaJson(), 'version': null},
        {...reservaJson(), 'vuelo': null},
        {...reservaJson(), 'iva_porcentaje': '1500'},
        {...reservaJson()}..remove('cantidad_asientos'),
        {...reservaJson(), 'vuelo': {'codigo': 'KT101'}},
      ]) {
        expect(() => Reserva.fromJson(mala), throwsA(isA<InvalidResponseFailure>()), reason: '$mala');
      }
    });
  });

  group('puede editarse', () {
    final ahora = DateTime(2026, 11, 11, 13, 19);

    test('confirmada y con vuelo futuro: sí', () {
      expect(Reserva.fromJson(reservaJson()).puedeEditarse(ahora: ahora), isTrue);
    });

    test('cancelada: no', () {
      expect(Reserva.fromJson(reservaJson(estado: 'cancelada')).puedeEditarse(ahora: ahora), isFalse);
    });

    test('vuelo que ya partió: no, incluso el mismo día y a la hora justa', () {
      expect(Reserva.fromJson(reservaJson(fecha: '2026-11-10')).puedeEditarse(ahora: ahora), isFalse);
      expect(Reserva.fromJson(reservaJson(fecha: '2026-11-11', horaSalida: '10:00:00')).puedeEditarse(ahora: ahora), isFalse);
      expect(Reserva.fromJson(reservaJson(fecha: '2026-11-11', horaSalida: '13:19:00')).puedeEditarse(ahora: ahora), isFalse);
      expect(Reserva.fromJson(reservaJson(fecha: '2026-11-11', horaSalida: '13:20:00')).puedeEditarse(ahora: ahora), isTrue);
    });
  });

  test('PaginaReservas lee la página y valida el contrato', () {
    final p = PaginaReservas.fromJson(paginaDeReservas(total: 25, pagina: 3));
    expect((p.total, p.pagina, p.totalPaginas, p.reservas.length), (25, 3, 3, 5));
    expect(() => PaginaReservas.fromJson({'total': 1}), throwsA(isA<InvalidResponseFailure>()));
  });
}
