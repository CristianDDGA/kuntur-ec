import '../services/api_exception.dart';
import '../services/rest_client.dart';
import 'vuelo.dart';

/// Vuelo con más ingresos dentro del resumen de ventas.
class VueloTop {
  const VueloTop({required this.codigo, required this.ruta, required this.asientos, required this.totalCentavos});

  final String codigo;
  final String ruta;
  final int asientos;
  final int totalCentavos;
}

/// Resumen de ventas (`GET /reservas/resumen`, solo administrador). Los montos viajan como texto y se guardan en centavos.
class ResumenVentas {
  const ResumenVentas({
    required this.confirmadas,
    required this.canceladas,
    required this.asientosVendidos,
    required this.subtotalCentavos,
    required this.ivaCentavos,
    required this.totalCentavos,
    required this.top,
  });

  factory ResumenVentas.fromJson(JsonMap json) {
    final confirmadas = json['reservas_confirmadas'];
    final canceladas = json['reservas_canceladas'];
    final asientos = json['asientos_vendidos'];
    final subtotal = Formatos.centavosDe(json['subtotal']);
    final iva = Formatos.centavosDe(json['iva']);
    final total = Formatos.centavosDe(json['total']);
    final top = json['vuelos_top'];
    if (confirmadas is! int || canceladas is! int || asientos is! int || subtotal == null || iva == null || total == null || top is! List) {
      throw const InvalidResponseFailure();
    }
    return ResumenVentas(
      confirmadas: confirmadas,
      canceladas: canceladas,
      asientosVendidos: asientos,
      subtotalCentavos: subtotal,
      ivaCentavos: iva,
      totalCentavos: total,
      top: [
        for (final t in top)
          if (t is Map<String, dynamic>)
            VueloTop(
              codigo: '${t['codigo']}',
              ruta: '${t['origen']} → ${t['destino']}',
              asientos: t['asientos'] is int ? t['asientos'] as int : 0,
              totalCentavos: Formatos.centavosDe(t['total']) ?? 0,
            ),
      ],
    );
  }

  final int confirmadas;
  final int canceladas;
  final int asientosVendidos;
  final int subtotalCentavos;
  final int ivaCentavos;
  final int totalCentavos;
  final List<VueloTop> top;
}
