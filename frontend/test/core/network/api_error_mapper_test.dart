import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/core/error/failures.dart';
import 'package:vuelos_app/core/network/api_error_mapper.dart';

void main() {
  const mapper = ApiErrorMapper();

  test('401 se traduce a UnauthorizedFailure con el mensaje de la API', () {
    final failure = mapper.fromResponse(401, '{"error":"no_autenticado","mensaje":"Token vencido"}');
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.mensaje, 'Token vencido');
  });

  test('errores controlados conservan código y estado', () {
    final failure = mapper.fromResponse(409, '{"error":"conflicto","mensaje":"Sin asientos"}');
    expect(failure, isA<ServerFailure>()
        .having((f) => f.statusCode, 'statusCode', 409)
        .having((f) => f.codigo, 'codigo', 'conflicto')
        .having((f) => f.mensaje, 'mensaje', 'Sin asientos'));
  });

  test('cuerpo no JSON usa un mensaje genérico', () {
    final failure = mapper.fromResponse(502, '<html>Bad Gateway</html>');
    expect(failure, isA<ServerFailure>().having((f) => f.codigo, 'codigo', isNull));
    expect(failure.mensaje, contains('502'));
  });
}
