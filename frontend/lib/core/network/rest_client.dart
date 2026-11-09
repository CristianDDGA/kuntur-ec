import '../error/failures.dart';

typedef JsonMap = Map<String, dynamic>;

/// Contrato para consumir los servicios REST (principio de Inversión de Dependencias).
/// Los datasources dependen de esta interfaz, nunca de `package:http`.
///
/// Todos los métodos lanzan un [Failure] cuando la petición no tiene éxito.
abstract interface class RestClient {
  Future<Object?> get(String path, {Map<String, String>? query});
  Future<Object?> post(String path, {Object? body});
  Future<Object?> put(String path, {Object? body});
  Future<Object?> delete(String path);

  /// Obtiene el cuerpo como texto XML (p. ej. el comprobante de una reserva).
  Future<String> getXml(String path);
}

/// Valida que la respuesta sea un objeto JSON.
JsonMap asJsonMap(Object? data) {
  if (data is JsonMap) return data;
  throw const InvalidResponseFailure();
}

/// Valida que la respuesta sea una lista de objetos JSON.
List<JsonMap> asJsonList(Object? data) {
  if (data is List && data.every((e) => e is JsonMap)) return data.cast<JsonMap>();
  throw const InvalidResponseFailure();
}
