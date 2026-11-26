import '../services/rest_client.dart';
import 'fallo.dart';
import 'vuelo.dart';

/// Destino de la portada: ciudad con vuelos próximos y su tarifa más baja (`GET /vuelos/destinos`).
class DestinoPopular {
  const DestinoPopular({required this.ciudad, required this.precioMinimoCentavos, required this.vuelos});

  factory DestinoPopular.fromJson(JsonMap json) {
    final ciudad = json['destino'];
    final centavos = Formatos.centavosDe(json['precio_minimo']);
    final vuelos = json['vuelos'];
    if (ciudad is! String || centavos == null || vuelos is! int) throw const InvalidResponseFailure();
    return DestinoPopular(ciudad: ciudad, precioMinimoCentavos: centavos, vuelos: vuelos);
  }

  final String ciudad;

  /// Tarifa mínima en centavos enteros: nunca se usa `double` para dinero.
  final int precioMinimoCentavos;
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

  String get lema =>
      _catalogo[ciudad.toLowerCase()]?.$2 ?? (vuelos == 1 ? '1 vuelo programado' : '${Formatos.entero(vuelos)} vuelos programados');
}
