import '../services/api_exception.dart';
import '../services/rest_client.dart';

enum EstadoTarifa { vigente, programada, anterior }

/// Tarifa de IVA. Contrato: {"id", "porcentaje": "15.00", "vigente_desde", "vigente_hasta", "estado"}.
class TarifaIva {
  const TarifaIva({
    required this.id,
    required this.porcentaje,
    required this.vigenteDesde,
    required this.vigenteHasta,
    required this.estado,
  });

  factory TarifaIva.fromJson(JsonMap json) {
    final id = json['id'];
    final porcentaje = json['porcentaje']?.toString();
    final desde = _fecha(json['vigente_desde']);
    final hastaTexto = json['vigente_hasta'];
    final hasta = hastaTexto == null ? null : _fecha(hastaTexto);
    final estado = EstadoTarifa.values.asNameMap()[json['estado']];
    if (id is! int ||
        porcentaje == null ||
        !RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(porcentaje) ||
        desde == null ||
        (hastaTexto != null && hasta == null) ||
        estado == null) {
      throw const InvalidResponseFailure();
    }
    return TarifaIva(id: id, porcentaje: porcentaje, vigenteDesde: desde, vigenteHasta: hasta, estado: estado);
  }

  final int id;

  /// Texto tal como lo envía el servidor ("15.00"); no se convierte a `double`.
  final String porcentaje;
  final DateTime vigenteDesde;
  final DateTime? vigenteHasta;
  final EstadoTarifa estado;

  /// "15.00" -> "15 %", "12.50" -> "12.5 %".
  String get porcentajeCorto {
    final partes = porcentaje.split('.');
    final decimales = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
    return decimales.isEmpty ? '${partes[0]} %' : '${partes[0]}.$decimales %';
  }

  static DateTime? _fecha(Object? valor) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(valor?.toString() ?? '');
    return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

/// Respuesta de `GET /iva`: la tarifa vigente (si la hay) y todo el historial.
class ResumenIva {
  const ResumenIva({required this.vigente, required this.tarifas});

  factory ResumenIva.fromJson(JsonMap json) {
    final lista = json['tarifas'];
    final vigente = json['vigente'];
    if (lista is! List || (vigente != null && vigente is! JsonMap)) throw const InvalidResponseFailure();
    return ResumenIva(
      vigente: vigente == null ? null : TarifaIva.fromJson(vigente as JsonMap),
      tarifas: asJsonList(lista).map(TarifaIva.fromJson).toList(),
    );
  }

  final TarifaIva? vigente;
  final List<TarifaIva> tarifas;
}
