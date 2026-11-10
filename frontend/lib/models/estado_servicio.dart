import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Estado de disponibilidad de la API.
/// Contrato de `GET /api/health`: {"estado": "ok", "servicio": "...", "hora": "ISO-8601"}.
class EstadoServicio {
  const EstadoServicio({required this.servicio, required this.disponible, required this.hora});

  factory EstadoServicio.fromJson(JsonMap json) {
    final servicio = json['servicio'];
    final estado = json['estado'];
    final hora = DateTime.tryParse(json['hora']?.toString() ?? '');
    if (servicio is! String || estado is! String || hora == null) {
      throw const InvalidResponseFailure();
    }
    return EstadoServicio(servicio: servicio, disponible: estado == 'ok', hora: hora);
  }

  final String servicio;
  final bool disponible;
  final DateTime hora;
}
