import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Vuelo del catálogo. Contrato de la API:
/// {"id", "codigo", "origen", "destino", "fecha": "AAAA-MM-DD", "hora_salida": "HH:MM:SS",
///  "hora_llegada", "precio": "75.50", "capacidad", "asientos_disponibles", "version"}.
class Vuelo {
  const Vuelo({
    required this.id,
    required this.codigo,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.horaLlegada,
    required this.precioCentavos,
    required this.capacidad,
    required this.asientosDisponibles,
    required this.version,
  });

  factory Vuelo.fromJson(JsonMap json) {
    final id = json['id'];
    final codigo = json['codigo'];
    final origen = json['origen'];
    final destino = json['destino'];
    final fecha = _fecha(json['fecha']);
    final salida = _hora(json['hora_salida']);
    final llegada = _hora(json['hora_llegada']);
    final precio = _centavos(json['precio']);
    final capacidad = json['capacidad'];
    final disponibles = json['asientos_disponibles'];
    final version = json['version'];
    if (id is! int ||
        codigo is! String ||
        origen is! String ||
        destino is! String ||
        fecha == null ||
        salida == null ||
        llegada == null ||
        precio == null ||
        capacidad is! int ||
        disponibles is! int ||
        version is! int) {
      throw const InvalidResponseFailure();
    }
    return Vuelo(
      id: id,
      codigo: codigo,
      origen: origen,
      destino: destino,
      fecha: fecha,
      horaSalida: salida,
      horaLlegada: llegada,
      precioCentavos: precio,
      capacidad: capacidad,
      asientosDisponibles: disponibles,
      version: version,
    );
  }

  final int id;
  final String codigo;
  final String origen;
  final String destino;
  final DateTime fecha;

  /// Hora del día (desde medianoche).
  final Duration horaSalida;
  final Duration horaLlegada;

  /// El precio se maneja en centavos enteros: nunca se usa `double` para dinero.
  final int precioCentavos;
  final int capacidad;
  final int asientosDisponibles;
  final int version;

  bool get agotado => asientosDisponibles <= 0;
  bool get pocosAsientos => !agotado && asientosDisponibles <= 5;

  /// Duración del vuelo; si la llegada es "antes" que la salida, cruza la medianoche.
  Duration get duracion {
    final d = horaLlegada - horaSalida;
    return d.isNegative ? d + const Duration(days: 1) : d;
  }

  static DateTime? _fecha(Object? valor) {
    final partes = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(valor?.toString() ?? '');
    if (partes == null) return null;
    return DateTime(int.parse(partes[1]!), int.parse(partes[2]!), int.parse(partes[3]!));
  }

  static Duration? _hora(Object? valor) {
    final partes = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(valor?.toString() ?? '');
    if (partes == null) return null;
    return Duration(hours: int.parse(partes[1]!), minutes: int.parse(partes[2]!));
  }

  /// "75.50" -> 7550.
  static int? _centavos(Object? valor) {
    final partes = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(valor?.toString() ?? '');
    if (partes == null) return null;
    return int.parse(partes[1]!) * 100 + int.parse((partes[2] ?? '').padRight(2, '0'));
  }
}

/// Filtros de la búsqueda y página pedida. Todo es opcional.
class FiltroVuelos {
  const FiltroVuelos({this.origen = '', this.destino = '', this.fecha, this.pagina = 1});

  /// Vuelos por página (el servidor acepta hasta 50).
  static const int porPagina = 10;

  final String origen;
  final String destino;
  final DateTime? fecha;
  final int pagina;

  bool get vacio => origen.isEmpty && destino.isEmpty && fecha == null;

  FiltroVuelos conPagina(int pagina) =>
      FiltroVuelos(origen: origen, destino: destino, fecha: fecha, pagina: pagina);

  /// Parámetros de la URL; solo se envían los filtros usados.
  Map<String, String> get consulta => {
        if (origen.isNotEmpty) 'origen': origen,
        if (destino.isNotEmpty) 'destino': destino,
        if (fecha != null) 'fecha': Formatos.fechaIso(fecha!),
        'pagina': '$pagina',
        'por_pagina': '$porPagina',
      };

  @override
  bool operator ==(Object other) =>
      other is FiltroVuelos &&
      other.origen == origen &&
      other.destino == destino &&
      other.fecha == fecha &&
      other.pagina == pagina;

  @override
  int get hashCode => Object.hash(origen, destino, fecha, pagina);
}

/// Una página de resultados. Contrato: {"total", "pagina", "por_pagina", "total_paginas", "vuelos": [...]}.
class PaginaVuelos {
  const PaginaVuelos({
    required this.vuelos,
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.totalPaginas,
  });

  factory PaginaVuelos.fromJson(JsonMap json) {
    final lista = json['vuelos'];
    final total = json['total'];
    final pagina = json['pagina'];
    final porPagina = json['por_pagina'];
    final totalPaginas = json['total_paginas'];
    if (lista is! List || total is! int || pagina is! int || porPagina is! int || totalPaginas is! int) {
      throw const InvalidResponseFailure();
    }
    return PaginaVuelos(
      vuelos: asJsonList(lista).map(Vuelo.fromJson).toList(),
      total: total,
      pagina: pagina,
      porPagina: porPagina,
      totalPaginas: totalPaginas,
    );
  }

  final List<Vuelo> vuelos;
  final int total;
  final int pagina;
  final int porPagina;
  final int totalPaginas;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;
}

/// Datos para crear un vuelo (solo administrador). No lleva código: lo genera el servidor.
class NuevoVuelo {
  const NuevoVuelo({
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.horaLlegada,
    required this.precio,
    required this.capacidad,
  });

  final String origen;
  final String destino;
  final DateTime fecha;
  final Duration horaSalida;
  final Duration horaLlegada;

  /// Texto con hasta 2 decimales, tal como lo escribió el usuario ("75.50").
  final String precio;
  final int capacidad;

  JsonMap toJson() => {
        'origen': origen,
        'destino': destino,
        'fecha': Formatos.fechaIso(fecha),
        'hora_salida': Formatos.hora(horaSalida),
        'hora_llegada': Formatos.hora(horaLlegada),
        'precio': precio, // como texto: así no se pierde precisión con decimales
        'capacidad': capacidad,
      };
}

/// Formato de fechas, horas y dinero para mostrar y para enviar.
class Formatos {
  const Formatos._();

  static const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic', //
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// 2026-12-01 (formato que exige la API).
  static String fechaIso(DateTime f) => '${f.year}-${_dos(f.month)}-${_dos(f.day)}';

  /// "mar 1 dic 2026".
  static String fecha(DateTime f) =>
      '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]} ${f.year}';

  /// "08:05".
  static String hora(Duration d) => '${_dos(d.inHours % 24)}:${_dos(d.inMinutes % 60)}';

  /// "1 h 05 min", "45 min".
  static String duracion(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    if (horas == 0) return '$minutos min';
    return '$horas h ${_dos(minutos)} min';
  }

  /// 7550 -> "\$75.50".
  static String dinero(int centavos) => '\$${centavos ~/ 100}.${_dos(centavos % 100)}';
}
