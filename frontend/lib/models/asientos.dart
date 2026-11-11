import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Mapa de asientos de un vuelo. Contrato: {"vuelo_id", "capacidad", "columnas": ["A","B","C","D"], "ocupados": ["2B"]}.
///
/// Los asientos que existen se deducen de la capacidad (fila + columna: 1A, 1B, 1C, 1D, 2A...), igual
/// que en el servidor; el API solo envía los ocupados.
class MapaAsientos {
  const MapaAsientos({required this.vueloId, required this.capacidad, required this.columnas, required this.ocupados});

  factory MapaAsientos.fromJson(JsonMap json) {
    final vueloId = json['vuelo_id'];
    final capacidad = json['capacidad'];
    final columnas = json['columnas'];
    final ocupados = json['ocupados'];
    if (vueloId is! int ||
        capacidad is! int ||
        capacidad < 1 ||
        capacidad > maxCapacidad ||
        columnas is! List ||
        columnas.isEmpty ||
        columnas.any((c) => c is! String || c.length != 1) ||
        ocupados is! List ||
        ocupados.any((o) => o is! String)) {
      throw const InvalidResponseFailure();
    }
    return MapaAsientos(
      vueloId: vueloId,
      capacidad: capacidad,
      columnas: columnas.cast<String>(),
      ocupados: ocupados.cast<String>().toSet(),
    );
  }

  /// El servidor no admite vuelos de más de 200 asientos; si llegara otra cosa, la respuesta no es válida.
  static const int maxCapacidad = 200;

  final int vueloId;
  final int capacidad;
  final List<String> columnas;
  final Set<String> ocupados;

  int get filas => (capacidad + columnas.length - 1) ~/ columnas.length;

  /// Número del asiento de la fila [fila] (desde 1) y la columna [columna] (desde 0), o `null` si no existe.
  String? asiento(int fila, int columna) {
    final posicion = (fila - 1) * columnas.length + columna;
    return posicion < capacidad ? '$fila${columnas[columna]}' : null;
  }

  /// Todos los asientos del vuelo, en orden.
  List<String> get todos => [
        for (var f = 1; f <= filas; f++)
          for (var c = 0; c < columnas.length; c++)
            if (asiento(f, c) != null) asiento(f, c)!,
      ];

  bool existe(String asiento) => todos.contains(asiento);

  int get libres => capacidad - ocupados.length;
}

/// Asientos que el usuario va marcando antes de confirmar. Inmutable: cada cambio devuelve uno nuevo.
class SeleccionAsientos {
  const SeleccionAsientos([this.elegidos = const {}]);

  /// Máximo de asientos por reserva (igual que el servidor).
  static const int maximo = 10;

  final Set<String> elegidos;

  bool get vacia => elegidos.isEmpty;
  int get cantidad => elegidos.length;
  bool get llena => cantidad >= maximo;
  bool contiene(String asiento) => elegidos.contains(asiento);

  /// Los asientos elegidos ordenados por fila y columna ("2A" antes que "10A").
  List<String> get ordenados {
    final lista = elegidos.toList();
    lista.sort((a, b) {
      final fa = int.parse(a.substring(0, a.length - 1));
      final fb = int.parse(b.substring(0, b.length - 1));
      return fa != fb ? fa.compareTo(fb) : a.compareTo(b);
    });
    return lista;
  }

  /// Marca o desmarca [asiento]. Si ya hay [maximo] elegidos, no deja agregar otro (devuelve `this`).
  SeleccionAsientos alternar(String asiento) {
    if (contiene(asiento)) return SeleccionAsientos({...elegidos}..remove(asiento));
    if (llena) return this;
    return SeleccionAsientos({...elegidos, asiento});
  }

  /// Quita de la selección los asientos que dejaron de estar libres.
  SeleccionAsientos sin(Iterable<String> asientos) => SeleccionAsientos({...elegidos}..removeAll(asientos));

  /// Deja la selección en blanco.
  SeleccionAsientos reiniciar() => const SeleccionAsientos();

  @override
  bool operator ==(Object other) =>
      other is SeleccionAsientos && other.elegidos.length == elegidos.length && other.elegidos.containsAll(elegidos);

  @override
  int get hashCode => Object.hashAllUnordered(elegidos);
}
