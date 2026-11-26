import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Un vuelo programado se vende; uno cancelado por la aerolínea queda solo en el historial.
enum EstadoVuelo {
  programado,
  cancelado;

  /// `null` si el servidor envía un estado desconocido.
  static EstadoVuelo? desde(Object? valor) {
    if (valor == null) return EstadoVuelo.programado; // respuestas anteriores al estado
    for (final e in values) {
      if (e.name == valor) return e;
    }
    return null;
  }
}

/// Vuelo del catálogo. Contrato de la API:
/// {"id", "codigo", "origen", "destino", "fecha": "AAAA-MM-DD", "hora_salida": "HH:MM:SS",
///  "hora_llegada", "precio": "75.50", "capacidad", "asientos_disponibles", "version",
///  "avion_id", "estado": "programado|cancelado", "motivo_cancelacion"}.
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
    this.avionId,
    this.estado = EstadoVuelo.programado,
    this.motivoCancelacion,
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
    final avionId = json['avion_id'];
    final estado = EstadoVuelo.desde(json['estado']);
    final motivo = json['motivo_cancelacion'];
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
        version is! int ||
        (avionId != null && avionId is! int) ||
        estado == null ||
        (motivo != null && motivo is! String)) {
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
      avionId: avionId as int?,
      estado: estado,
      motivoCancelacion: motivo as String?,
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

  /// Avión que opera el vuelo (`null` en vuelos creados antes de existir los aviones).
  final int? avionId;
  final EstadoVuelo estado;

  /// Por qué la aerolínea canceló el vuelo (solo en vuelos cancelados).
  final String? motivoCancelacion;

  bool get cancelado => estado == EstadoVuelo.cancelado;
  int get asientosVendidos => capacidad - asientosDisponibles;

  /// Con asientos vendidos el administrador solo puede cambiar fecha, horas y precio.
  bool get tieneReservas => asientosVendidos > 0;

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

  static int? _centavos(Object? valor) => Formatos.centavosDe(valor);
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
    required this.avionId,
  });

  final String origen;
  final String destino;
  final DateTime fecha;
  final Duration horaSalida;
  final Duration horaLlegada;

  /// Texto con hasta 2 decimales, tal como lo escribió el usuario ("75.50").
  final String precio;

  /// Avión que opera el vuelo: su capacidad (filas x 4) define los asientos.
  final int avionId;

  JsonMap toJson() => {
        'origen': origen,
        'destino': destino,
        'fecha': Formatos.fechaIso(fecha),
        'hora_salida': Formatos.hora(horaSalida),
        'hora_llegada': Formatos.hora(horaLlegada),
        'precio': precio, // como texto: así no se pierde precisión con decimales
        'avion_id': avionId,
      };
}

/// Cambios de un vuelo existente (solo administrador). Se envían todos los datos y la `version`
/// leída: si otro administrador lo cambió antes, el servidor responde 409.
class EdicionVuelo {
  const EdicionVuelo({
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.horaLlegada,
    required this.precio,
    required this.version,
    this.avionId,
  });

  final String origen;
  final String destino;
  final DateTime fecha;
  final Duration horaSalida;
  final Duration horaLlegada;
  final String precio;
  final int version;

  /// Solo se envía si cambia el avión (no se puede con asientos vendidos).
  final int? avionId;

  JsonMap toJson() => {
        'origen': origen,
        'destino': destino,
        'fecha': Formatos.fechaIso(fecha),
        'hora_salida': Formatos.hora(horaSalida),
        'hora_llegada': Formatos.hora(horaLlegada),
        'precio': precio,
        if (avionId != null) 'avion_id': avionId,
        'version': version,
      };
}

/// Un vuelo en el listado del administrador, con lo que necesita para decidir qué hacer.
class VueloGestionado {
  const VueloGestionado({required this.vuelo, required this.yaPartio});

  final Vuelo vuelo;

  /// Lo calcula el servidor con la hora de Ecuador (no el reloj del navegador).
  final bool yaPartio;

  /// Solo se edita o cancela un vuelo programado que aún no parte.
  bool get gestionable => !vuelo.cancelado && !yaPartio;
}

/// Filtro del listado del administrador (`null` = todos).
class FiltroGestion {
  const FiltroGestion({this.estado, this.pagina = 1});

  static const int porPagina = 10;

  final EstadoVuelo? estado;
  final int pagina;

  Map<String, String> get consulta => {
        if (estado != null) 'estado': estado!.name,
        'pagina': '$pagina',
        'por_pagina': '$porPagina',
      };

  @override
  bool operator ==(Object other) => other is FiltroGestion && other.estado == estado && other.pagina == pagina;

  @override
  int get hashCode => Object.hash(estado, pagina);
}

/// Página del listado del administrador. Contrato: el de [PaginaVuelos] y cada vuelo con
/// `ya_partio` (bool) y `asientos_vendidos`.
class PaginaGestion {
  const PaginaGestion({
    required this.vuelos,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });

  factory PaginaGestion.fromJson(JsonMap json) {
    final base = PaginaVuelos.fromJson(json);
    final partidos = [for (final v in json['vuelos'] as List) asJsonMap(v)['ya_partio']];
    if (partidos.any((p) => p is! bool)) throw const InvalidResponseFailure();
    return PaginaGestion(
      vuelos: [
        for (var i = 0; i < base.vuelos.length; i++)
          VueloGestionado(vuelo: base.vuelos[i], yaPartio: partidos[i] as bool),
      ],
      total: base.total,
      pagina: base.pagina,
      totalPaginas: base.totalPaginas,
    );
  }

  final List<VueloGestionado> vuelos;
  final int total;
  final int pagina;
  final int totalPaginas;
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

  /// "75.50" -> 7550 (null si no es un monto válido). Los montos nunca pasan por `double`.
  static int? centavosDe(Object? valor) {
    final partes = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(valor?.toString() ?? '');
    if (partes == null) return null;
    return int.parse(partes[1]!) * 100 + int.parse((partes[2] ?? '').padRight(2, '0'));
  }

  /// "15.00" -> "15 %", "12.50" -> "12.5 %".
  static String porcentaje(String texto) {
    final partes = texto.split('.');
    final decimales = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
    return decimales.isEmpty ? '${partes[0]} %' : '${partes[0]}.$decimales %';
  }

  /// Entero con separador de miles con coma: `1284` -> `"1,284"`.
  static String entero(int valor) {
    final signo = valor < 0 ? '-' : '';
    final digitos = valor.abs().toString();
    final buffer = StringBuffer();
    final longitud = digitos.length;
    for (var i = 0; i < longitud; i++) {
      if (i > 0 && (longitud - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digitos[i]);
    }
    return '$signo${buffer.toString()}';
  }

  /// Formato monetario internacional estándar:
  /// Símbolo + Espacio + Miles con coma + Decimales con punto:
  /// 7550 -> "$ 75.50"  /  1000000 -> "$ 10,000.00"  /  -7550 -> "-$ 75.50".
  static String dinero(int centavos) {
    final signo = centavos < 0 ? '-' : '';
    final absCentavos = centavos.abs();
    final enteros = entero(absCentavos ~/ 100);
    final decimales = _dos(absCentavos % 100);
    return '$signo\$ $enteros.$decimales';
  }
}
