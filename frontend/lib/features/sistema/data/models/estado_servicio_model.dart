import '../../../../core/error/failures.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/estado_servicio.dart';

/// Contrato de `GET /api/health`: {"estado": "ok", "servicio": "...", "hora": "ISO-8601"}.
class EstadoServicioModel extends EstadoServicio {
  const EstadoServicioModel({required super.servicio, required super.disponible, required super.hora});

  factory EstadoServicioModel.fromJson(JsonMap json) {
    final servicio = json['servicio'];
    final estado = json['estado'];
    final hora = DateTime.tryParse(json['hora']?.toString() ?? '');
    if (servicio is! String || estado is! String || hora == null) {
      throw const InvalidResponseFailure();
    }
    return EstadoServicioModel(servicio: servicio, disponible: estado == 'ok', hora: hora);
  }
}
