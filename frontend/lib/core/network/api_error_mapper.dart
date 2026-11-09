import 'dart:convert';

import '../error/failures.dart';

/// Traduce una respuesta HTTP fallida de la API al [Failure] correspondiente.
/// Formato esperado del cuerpo: {"error": "<codigo>", "mensaje": "<texto>"}.
class ApiErrorMapper {
  const ApiErrorMapper();

  Failure fromResponse(int statusCode, String body) {
    final (codigo, mensaje) = _parse(body);
    if (statusCode == 401) {
      return mensaje == null ? const UnauthorizedFailure() : UnauthorizedFailure(mensaje);
    }
    return ServerFailure(
      mensaje ?? 'Error inesperado del servidor ($statusCode).',
      statusCode: statusCode,
      codigo: codigo,
    );
  }

  (String?, String?) _parse(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return (data['error'] as String?, data['mensaje'] as String?);
      }
    } on FormatException {
      // Cuerpo vacío o no JSON (p. ej. error de un proxy): se usa el mensaje genérico.
    }
    return (null, null);
  }
}
