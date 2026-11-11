import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/validadores_vuelo.dart';

void main() {
  group('ciudad', () {
    test('acepta nombres reales', () {
      for (final ok in ['Quito', 'San Cristóbal', 'Santo Domingo de los Tsáchilas', 'Puerto Ayora', 'Nueva Loja']) {
        expect(ValidadoresVuelo.ciudad(ok), isNull, reason: ok);
      }
    });

    test('rechaza vacío, símbolos, números, emojis y control', () {
      for (final mal in ['', '   ', 'Quito1', 'Qui<to>', 'Quito 🙂', 'Qu\nito', 'A', '.-.']) {
        expect(ValidadoresVuelo.ciudad(mal), isNotNull, reason: mal);
      }
    });

    test('el largo máximo es el de la columna (80)', () {
      expect(ValidadoresVuelo.ciudad('a' * 80), isNull);
      expect(ValidadoresVuelo.ciudad('a' * 81), isNotNull);
    });

    test('el filtro es opcional', () {
      expect(ValidadoresVuelo.filtroCiudad(''), isNull);
      expect(ValidadoresVuelo.filtroCiudad('   '), isNull);
      expect(ValidadoresVuelo.filtroCiudad('Quito'), isNull);
      expect(ValidadoresVuelo.filtroCiudad('Qu1to'), isNotNull);
    });

    test('destino distinto del origen sin importar mayúsculas ni espacios', () {
      expect(ValidadoresVuelo.destinoDistinto('Guayaquil', 'Quito'), isNull);
      expect(ValidadoresVuelo.destinoDistinto('  quito ', 'Quito'), isNotNull);
    });
  });

  group('precio', () {
    test('acepta hasta 2 decimales y coma decimal', () {
      for (final ok in ['75', '75.5', '75.50', '75,50', '0.01', '10000', '10000.00']) {
        expect(ValidadoresVuelo.precio(ok), isNull, reason: ok);
      }
    });

    test('rechaza cero, negativos, texto, exceso y 3 decimales', () {
      for (final mal in ['', '0', '0.00', '-5', 'abc', '10000.01', '75.505', '1e3', '7 5']) {
        expect(ValidadoresVuelo.precio(mal), isNotNull, reason: mal);
      }
    });

    test('normaliza la coma para enviarlo', () => expect(ValidadoresVuelo.normalizarPrecio(' 75,5 '), '75.5'));
  });

  group('capacidad', () {
    test('1 a 900, entero', () {
      for (final ok in ['1', '80', '900']) {
        expect(ValidadoresVuelo.capacidad(ok), isNull, reason: ok);
      }
      for (final mal in ['', '0', '901', '-3', '8.5', 'ocho']) {
        expect(ValidadoresVuelo.capacidad(mal), isNotNull, reason: mal);
      }
    });
  });

  group('fecha y horas', () {
    final hoy = DateTime(2026, 11, 11, 15, 30);

    test('desde hoy hasta 2 años', () {
      expect(ValidadoresVuelo.fecha(null, hoy: hoy), isNotNull);
      expect(ValidadoresVuelo.fecha(DateTime(2026, 11, 10), hoy: hoy), isNotNull);
      expect(ValidadoresVuelo.fecha(DateTime(2026, 11, 11), hoy: hoy), isNull);
      expect(ValidadoresVuelo.fecha(DateTime(2028, 11, 10), hoy: hoy), isNull); // día 730
      expect(ValidadoresVuelo.fecha(DateTime(2028, 11, 11), hoy: hoy), isNotNull);
    });

    test('la llegada debe existir y ser distinta a la salida', () {
      const ocho = Duration(hours: 8);
      expect(ValidadoresVuelo.llegada(null, ocho), isNotNull);
      expect(ValidadoresVuelo.llegada(ocho, ocho), isNotNull);
      expect(ValidadoresVuelo.llegada(const Duration(hours: 9), ocho), isNull);
      expect(ValidadoresVuelo.llegada(const Duration(hours: 1), ocho), isNull); // cruza medianoche
    });
  });
}
