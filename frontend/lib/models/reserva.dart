import '../services/api_exception.dart';
import '../services/rest_client.dart';
import 'vuelo.dart';

enum EstadoReserva { confirmada, cancelada }

/// Resumen del vuelo que viene dentro de una reserva.
class ResumenVuelo {
  const ResumenVuelo({
    required this.codigo,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.horaLlegada,
  });

  factory ResumenVuelo.fromJson(JsonMap json) {
    final codigo = json['codigo'];
    final origen = json['origen'];
    final destino = json['destino'];
    final fecha = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(json['fecha']?.toString() ?? '');
    final salida = _hora(json['hora_salida']);
    final llegada = _hora(json['hora_llegada']);
    if (codigo is! String || origen is! String || destino is! String || fecha == null || salida == null || llegada == null) {
      throw const InvalidResponseFailure();
    }
    return ResumenVuelo(
      codigo: codigo,
      origen: origen,
      destino: destino,
      fecha: DateTime(int.parse(fecha[1]!), int.parse(fecha[2]!), int.parse(fecha[3]!)),
      horaSalida: salida,
      horaLlegada: llegada,
    );
  }

  final String codigo;
  final String origen;
  final String destino;
  final DateTime fecha;
  final Duration horaSalida;
  final Duration horaLlegada;

  /// Momento de salida. Un vuelo "ya partió" cuando llega su fecha y hora.
  DateTime get salida => fecha.add(horaSalida);

  bool yaPartio({DateTime? ahora}) => !salida.isAfter(ahora ?? DateTime.now());

  static Duration? _hora(Object? valor) {
    final m = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(valor?.toString() ?? '');
    return m == null ? null : Duration(hours: int.parse(m[1]!), minutes: int.parse(m[2]!));
  }
}

/// Reserva. Contrato: {"id", "vuelo_id", "cantidad_asientos", "subtotal": "178.00", "iva_porcentaje": "15.00",
/// "iva_valor", "total", "estado", "fecha_reserva", "version", "vuelo": {...}}.
class Reserva {
  const Reserva({
    required this.id,
    required this.vueloId,
    required this.cantidad,
    required this.subtotalCentavos,
    required this.ivaPorcentaje,
    required this.ivaCentavos,
    required this.totalCentavos,
    required this.estado,
    required this.fechaReserva,
    required this.version,
    required this.vuelo,
    required this.asientos,
  });

  factory Reserva.fromJson(JsonMap json) {
    final id = json['id'];
    final vueloId = json['vuelo_id'];
    final cantidad = json['cantidad_asientos'];
    final subtotal = Formatos.centavosDe(json['subtotal']);
    final porcentaje = json['iva_porcentaje']?.toString();
    final iva = Formatos.centavosDe(json['iva_valor']);
    final total = Formatos.centavosDe(json['total']);
    final estado = EstadoReserva.values.asNameMap()[json['estado']];
    final version = json['version'];
    final vuelo = json['vuelo'];
    final asientos = json['asientos'];
    if (id is! int ||
        vueloId is! int ||
        cantidad is! int ||
        subtotal == null ||
        porcentaje == null ||
        !RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(porcentaje) ||
        iva == null ||
        total == null ||
        estado == null ||
        version is! int ||
        vuelo is! JsonMap ||
        asientos is! List ||
        asientos.any((a) => a is! String)) {
      throw const InvalidResponseFailure();
    }
    return Reserva(
      id: id,
      vueloId: vueloId,
      cantidad: cantidad,
      subtotalCentavos: subtotal,
      ivaPorcentaje: porcentaje,
      ivaCentavos: iva,
      totalCentavos: total,
      estado: estado,
      fechaReserva: DateTime.tryParse(json['fecha_reserva']?.toString() ?? ''),
      version: version,
      vuelo: ResumenVuelo.fromJson(vuelo),
      asientos: asientos.cast<String>(),
    );
  }

  final int id;
  final int vueloId;
  final int cantidad;
  final int subtotalCentavos;
  final String ivaPorcentaje;
  final int ivaCentavos;
  final int totalCentavos;
  final EstadoReserva estado;
  final DateTime? fechaReserva;

  /// Control de concurrencia: se envía al modificar; si otro la cambió antes, el servidor responde 409.
  final int version;
  final ResumenVuelo vuelo;

  /// Asientos de la reserva, ordenados ("1A", "1B"...). También en las canceladas, como historial.
  final List<String> asientos;

  bool get cancelada => estado == EstadoReserva.cancelada;

  /// Solo se puede modificar o cancelar una reserva confirmada de un vuelo que aún no parte.
  bool puedeEditarse({DateTime? ahora}) => !cancelada && !vuelo.yaPartio(ahora: ahora);

  /// Número de comprobante: "KEC-00000058".
  String get numero => 'KEC-${id.toString().padLeft(8, '0')}';
}

/// Una página del historial. Contrato: {"total", "pagina", "por_pagina", "total_paginas", "reservas": [...]}.
class PaginaReservas {
  const PaginaReservas({
    required this.reservas,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });

  factory PaginaReservas.fromJson(JsonMap json) {
    final lista = json['reservas'];
    final total = json['total'];
    final pagina = json['pagina'];
    final paginas = json['total_paginas'];
    if (lista is! List || total is! int || pagina is! int || paginas is! int) throw const InvalidResponseFailure();
    return PaginaReservas(
      reservas: asJsonList(lista).map(Reserva.fromJson).toList(),
      total: total,
      pagina: pagina,
      totalPaginas: paginas,
    );
  }

  final List<Reserva> reservas;
  final int total;
  final int pagina;
  final int totalPaginas;
}
