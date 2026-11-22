import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Avión registrado. Contrato: {"id", "matricula", "modelo", "filas", "capacidad"} (capacidad = filas x 4).
class Avion {
  const Avion({
    required this.id,
    required this.matricula,
    required this.modelo,
    required this.filas,
    required this.capacidad,
  });

  factory Avion.fromJson(JsonMap json) {
    final id = json['id'];
    final matricula = json['matricula'];
    final modelo = json['modelo'];
    final filas = json['filas'];
    final capacidad = json['capacidad'];
    if (id is! int || matricula is! String || modelo is! String || filas is! int || capacidad is! int) {
      throw const InvalidResponseFailure();
    }
    return Avion(id: id, matricula: matricula, modelo: modelo, filas: filas, capacidad: capacidad);
  }

  final int id;
  final String matricula;
  final String modelo;
  final int filas;
  final int capacidad;

  /// Texto para listas y selectores: "HC-ABC · Airbus A320 · 120 asientos".
  String get etiqueta => '$matricula · $modelo · $capacidad asientos';
}

/// Una fila del CSV con su problema ("línea 3: matrícula inválida").
class ErrorCsv {
  const ErrorCsv({required this.linea, required this.mensaje});

  factory ErrorCsv.fromJson(Object? json) {
    if (json is! JsonMap || json['linea'] is! int || json['mensaje'] is! String) throw const InvalidResponseFailure();
    return ErrorCsv(linea: json['linea'] as int, mensaje: json['mensaje'] as String);
  }

  final int linea;
  final String mensaje;
}

/// Fila válida del CSV tal como se importaría.
class FilaPrevia {
  const FilaPrevia({
    required this.linea,
    required this.matricula,
    required this.modelo,
    required this.filas,
    required this.capacidad,
    required this.yaExiste,
  });

  factory FilaPrevia.fromJson(Object? json) {
    if (json is! JsonMap) throw const InvalidResponseFailure();
    final linea = json['linea'];
    final matricula = json['matricula'];
    final modelo = json['modelo'];
    final filas = json['filas'];
    final capacidad = json['capacidad'];
    final yaExiste = json['ya_existe'];
    if (linea is! int ||
        matricula is! String ||
        modelo is! String ||
        filas is! int ||
        capacidad is! int ||
        yaExiste is! bool) {
      throw const InvalidResponseFailure();
    }
    return FilaPrevia(
      linea: linea,
      matricula: matricula,
      modelo: modelo,
      filas: filas,
      capacidad: capacidad,
      yaExiste: yaExiste,
    );
  }

  final int linea;
  final String matricula;
  final String modelo;
  final int filas;
  final int capacidad;
  final bool yaExiste;
}

/// Respuesta de `POST /aviones/importacion/validar`: qué se importaría y qué errores tiene el archivo.
class ResumenCsv {
  const ResumenCsv({
    required this.totalFilas,
    required this.nuevos,
    required this.existentes,
    required this.errores,
    required this.vistaPrevia,
  });

  factory ResumenCsv.fromJson(JsonMap json) {
    final total = json['total_filas'];
    final nuevos = json['nuevos'];
    final existentes = json['existentes'];
    final errores = json['errores'];
    final vista = json['vista_previa'];
    if (total is! int || nuevos is! int || existentes is! List || errores is! List || vista is! List) {
      throw const InvalidResponseFailure();
    }
    return ResumenCsv(
      totalFilas: total,
      nuevos: nuevos,
      existentes: existentes.whereType<String>().toList(),
      errores: errores.map(ErrorCsv.fromJson).toList(),
      vistaPrevia: vista.map(FilaPrevia.fromJson).toList(),
    );
  }

  final int totalFilas;
  final int nuevos;
  final List<String> existentes;
  final List<ErrorCsv> errores;
  final List<FilaPrevia> vistaPrevia;

  bool get tieneErrores => errores.isNotEmpty;

  /// Solo se puede importar si el archivo está limpio y trae al menos un avión nuevo.
  bool get sePuedeImportar => !tieneErrores && nuevos > 0;
}

/// Respuesta de `POST /aviones/importacion`.
class ResultadoImportacion {
  const ResultadoImportacion({required this.creados, required this.omitidos});

  factory ResultadoImportacion.fromJson(JsonMap json) {
    final creados = json['creados'];
    final omitidos = json['omitidos'];
    if (creados is! int || omitidos is! List) throw const InvalidResponseFailure();
    return ResultadoImportacion(creados: creados, omitidos: omitidos.whereType<String>().toList());
  }

  final int creados;
  final List<String> omitidos;
}
