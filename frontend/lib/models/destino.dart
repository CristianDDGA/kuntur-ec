import '../services/api_exception.dart';
import '../services/rest_client.dart';

/// Destino de la portada: ciudad con vuelos próximos y su tarifa más baja (`GET /vuelos/destinos`).
class DestinoPopular {
  const DestinoPopular({required this.ciudad, required this.precioMinimo, required this.vuelos});

  factory DestinoPopular.fromJson(JsonMap json) {
    final ciudad = json['destino'];
    final precio = double.tryParse('${json['precio_minimo']}');
    final vuelos = json['vuelos'];
    if (ciudad is! String || precio == null || vuelos is! int) throw const InvalidResponseFailure();
    return DestinoPopular(ciudad: ciudad, precioMinimo: precio, vuelos: vuelos);
  }

  final String ciudad;
  final double precioMinimo;
  final int vuelos;

  /// Código y lema conocidos de las ciudades del país; para otra ciudad se deducen del nombre.
  static const _catalogo = {
    'guayaquil': ('GYE', 'Perla del Pacífico · Puerto y calor'),
    'manta': ('MEC', 'Costa manabita · Playas y gastronomía'),
    'coca': ('OCC', 'Puerta a la Amazonía ecuatoriana'),
    'quito': ('UIO', 'Mitad del Mundo · Centro Histórico'),
    'cuenca': ('CUE', 'Ciudad patrimonio · Arte y tradición'),
    'galápagos': ('GPS', 'Islas encantadas · Naturaleza única'),
    'loja': ('LOH', 'Capital musical · Sur del país'),
  };

  String get codigo {
    final conocido = _catalogo[ciudad.toLowerCase()];
    if (conocido != null) return conocido.$1;
    final letras = ciudad.replaceAll(RegExp('[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    return (letras.length >= 3 ? letras.substring(0, 3) : letras).toUpperCase();
  }

  String get lema => _catalogo[ciudad.toLowerCase()]?.$2 ?? (vuelos == 1 ? '1 vuelo programado' : '$vuelos vuelos programados');
}
