import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/sesion.dart';
import 'package:vuelos_app/models/usuario.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('Usuario.fromJson', () {
    test('lee el contrato de la API', () {
      final u = Usuario.fromJson(usuarioAna);
      expect((u.id, u.nombre, u.correo, u.rol), (7, 'Ana Torres', 'ana@correo.com', Rol.cliente));
      expect(u.fechaRegistro, DateTime.parse('2026-11-10T15:04:04+00:00'));
      expect(u.esAdmin, isFalse);
    });

    test('reconoce al administrador', () {
      expect(Usuario.fromJson({...usuarioAna, 'rol': 'admin'}).esAdmin, isTrue);
    });

    test('la fecha es opcional', () {
      expect(Usuario.fromJson({...usuarioAna, 'fecha_registro': null}).fechaRegistro, isNull);
    });

    for (final cambio in <Map<String, Object?>>[
      {'id': '7'}, {'id': null}, {'nombre': 5}, {'correo': null}, {'rol': 'superusuario'}, {'rol': null},
    ]) {
      test('una respuesta inesperada ($cambio) lanza InvalidResponseFailure', () {
        expect(() => Usuario.fromJson({...usuarioAna, ...cambio}), throwsA(isA<InvalidResponseFailure>()));
      });
    }

    test('iniciales', () {
      Usuario con(String nombre) => Usuario.fromJson({...usuarioAna, 'nombre': nombre});
      expect(con('Ana Torres').iniciales, 'AT');
      expect(con('Ana').iniciales, 'A');
      expect(con('juan carlos pérez lópez').iniciales, 'JL');
      expect(con('  ').iniciales, '?');
    });
  });

  group('Sesion.fromJson', () {
    test('lee la respuesta del login', () {
      final s = Sesion.fromJson(respuestaLogin);
      expect(s.token, 'jwt-de-prueba');
      expect(s.expira, DateTime.parse('2026-11-10T16:04:04+00:00'));
      expect(s.usuario.nombre, 'Ana Torres');
    });

    for (final cambio in <Map<String, Object?>>[
      {'token': null}, {'token': ''}, {'expira': 'ayer'}, {'expira': null}, {'usuario': 'x'}, {'usuario': null},
    ]) {
      test('una respuesta inesperada ($cambio) lanza InvalidResponseFailure', () {
        expect(() => Sesion.fromJson({...respuestaLogin, ...cambio}), throwsA(isA<InvalidResponseFailure>()));
      });
    }
  });
}
