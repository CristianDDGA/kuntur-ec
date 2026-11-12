import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/expiracion_token.dart';

import '../helpers/fakes.dart';

String _jwt(Object? carga) {
  final cuerpo = base64Url.encode(utf8.encode(carga is String ? carga : jsonEncode(carga))).replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiJ9.$cuerpo.firma';
}

void main() {
  test('lee el vencimiento de un JWT', () {
    final vence = ExpiracionToken.de(_jwt({'exp': 1893456000})); // 2030-01-01 00:00 UTC
    expect(vence, DateTime.utc(2030, 1, 1));
  });

  test('funciona con el JWT que arma el helper de pruebas', () {
    final ahora = DateTime.utc(2026, 11, 12, 10);
    final vence = ExpiracionToken.de(jwtQueVenceEn(const Duration(minutes: 60), ahora: ahora));
    expect(vence, DateTime.utc(2026, 11, 12, 11));
  });

  test('un token que no se puede leer da null (nunca lanza)', () {
    for (final malo in <String>[
      '',
      'abc',
      'a.b',
      'a.b.c.d',
      'a.%%%.c',
      'a.${base64Url.encode(utf8.encode('no es json'))}.c',
      _jwt('[1,2,3]'),
      _jwt({'sub': '7'}),
      _jwt({'exp': 'mañana'}),
      _jwt({'exp': -5}),
      _jwt({'exp': 0}),
      _jwt({'exp': null}),
      _jwt({'exp': true}),
    ]) {
      expect(ExpiracionToken.de(malo), isNull, reason: malo);
    }
  });
}
