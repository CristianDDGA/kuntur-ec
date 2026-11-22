import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/asientos.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('MapaAsientos', () {
    test('lee el contrato y genera los asientos por fila y columna', () {
      final m = MapaAsientos.fromJson(mapaJson(capacidad: 6, ocupados: ['1B']));
      expect(m.todos, ['1A', '1B', '1C', '1D', '2A', '2B']);
      expect(m.filas, 2);
      expect(m.ocupados, {'1B'});
      expect(m.libres, 5);
      expect(m.asiento(2, 2), isNull); // el vuelo de 6 asientos no tiene 2C
      expect(m.existe('2B'), isTrue);
      expect(m.existe('2C'), isFalse);
    });

    test('un vuelo de 200 asientos tiene 50 filas y 200 asientos distintos', () {
      final m = MapaAsientos.fromJson(mapaJson(capacidad: 200));
      expect(m.filas, 50);
      expect(m.todos.length, 200);
      expect(m.todos.toSet().length, 200);
      expect(m.todos.last, '50D');
    });

    test('más de 200 asientos o una respuesta mal formada es InvalidResponseFailure', () {
      for (final malo in <Map<String, Object?>>[
        mapaJson(capacidad: 201),
        mapaJson(capacidad: 0),
        {...mapaJson(), 'capacidad': '12'},
        {...mapaJson(), 'columnas': <Object>[]},
        {...mapaJson(), 'columnas': ['AB']},
        {...mapaJson(), 'ocupados': 'nada'},
        {...mapaJson(), 'ocupados': [1]},
        {...mapaJson()}..remove('vuelo_id'),
      ]) {
        expect(() => MapaAsientos.fromJson(malo), throwsA(isA<InvalidResponseFailure>()), reason: '$malo');
      }
    });
  });

  group('SeleccionAsientos', () {
    test('marcar y desmarcar un asiento', () {
      var s = const SeleccionAsientos();
      expect(s.vacia, isTrue);
      s = s.alternar('1A');
      expect(s.contiene('1A'), isTrue);
      s = s.alternar('1A');
      expect(s.vacia, isTrue);
    });

    test('no pasa de 10 asientos: el undécimo se ignora', () {
      var s = const SeleccionAsientos();
      for (var i = 1; i <= 10; i++) {
        s = s.alternar('${i}A');
      }
      expect(s.cantidad, 10);
      expect(s.llena, isTrue);
      final once = s.alternar('11A');
      expect(identical(once, s), isTrue);
      expect(once.cantidad, 10);
      // pero sí se puede quitar uno y poner otro
      expect(s.alternar('3A').alternar('11A').cantidad, 10);
    });

    test('se ordena por fila y luego por columna, no como texto', () {
      final s = const SeleccionAsientos().alternar('10A').alternar('2B').alternar('2A').alternar('1D');
      expect(s.ordenados, ['1D', '2A', '2B', '10A']);
    });

    test('reiniciar deja la selección en blanco', () {
      final s = const SeleccionAsientos().alternar('1A').alternar('1B').reiniciar();
      expect(s.vacia, isTrue);
    });

    test('quitar los que ya no están libres deja el resto', () {
      final s = const SeleccionAsientos().alternar('1A').alternar('1B').alternar('1C').sin(['1B', '9Z']);
      expect(s.ordenados, ['1A', '1C']);
    });

    test('dos selecciones con los mismos asientos son iguales sin importar el orden', () {
      expect(const SeleccionAsientos({'1A', '1B'}), const SeleccionAsientos({'1B', '1A'}));
      expect(const SeleccionAsientos({'1A'}), isNot(const SeleccionAsientos({'1B'})));
    });

    test('es inmutable: alternar no modifica la selección original', () {
      const original = SeleccionAsientos({'1A'});
      original.alternar('1B');
      expect(original.elegidos, {'1A'});
    });
  });

  test('ServerFailure expone los asientos ocupados de un 409', () {
    const f = ServerFailure('ocupado', statusCode: 409, detalles: {'asientos_ocupados': ['1A', '2B']});
    expect(f.asientosOcupados, ['1A', '2B']);
    expect(const ServerFailure('x', statusCode: 409).asientosOcupados, isEmpty);
    expect(const ServerFailure('x', statusCode: 409, detalles: {'asientos_ocupados': 'raro'}).asientosOcupados, isEmpty);
  });
}
