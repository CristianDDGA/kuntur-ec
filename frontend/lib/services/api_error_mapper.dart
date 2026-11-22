import 'dart:convert';

import 'api_exception.dart';

/// Traduce una respuesta HTTP fallida de la API al [Failure] correspondiente.
/// Formato esperado del cuerpo: {"error": "<codigo>", "mensaje": "<texto>"}.
class ApiErrorMapper {
  const ApiErrorMapper();

  Failure fromResponse(int statusCode, String body) {
    final (codigo, mensaje, detalles) = _parse(body);
    if (statusCode == 401) {
      return mensaje == null ? const UnauthorizedFailure() : UnauthorizedFailure(mensaje);
    }
    return ServerFailure(
      mensaje ?? 'Error inesperado del servidor ($statusCode).',
      statusCode: statusCode,
      codigo: codigo,
      detalles: detalles,
    );
  }

  (String?, String?, Map<String, dynamic>) _parse(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        final mensaje = data['mensaje'];
        final extra = Map<String, dynamic>.of(data)..remove('error')..remove('mensaje');
        return (error is String ? error : null, mensaje is String ? mensaje : null, extra);
      }
    } on FormatException {
      // Cuerpo vacío o no JSON (p. ej. error de un proxy): se usa el mensaje genérico.
    }
    return (null, null, const {});
  }
}
