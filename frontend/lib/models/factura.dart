import 'package:xml/xml.dart';

import '../services/api_exception.dart';
import 'vuelo.dart';

/// Comprobante (factura) de una reserva, leído del XML que genera el servidor.
///
/// Estructura del XML (la de la práctica de clase):
/// `factura/{cabecera/{numero,fecha}, cliente/{nombre,correo}, Detalle/producto/{Nombre,Asientos?,Cantidad,
/// PrecioUnitario,Subtotal}, Totales/{Subtotal,PorcentajeIVA,IVA,Total}, Estado}`.
/// Los montos son los guardados en la reserva; la app solo los muestra.
class Factura {
  const Factura({
    required this.numero,
    required this.fecha,
    required this.clienteNombre,
    required this.clienteCorreo,
    required this.descripcion,
    required this.asientos,
    required this.cantidad,
    required this.precioUnitarioCentavos,
    required this.subtotalCentavos,
    required this.ivaPorcentaje,
    required this.ivaCentavos,
    required this.totalCentavos,
    required this.estado,
    required this.xml,
  });

  /// Lee el XML. Cualquier cosa que no sea una factura válida lanza [InvalidResponseFailure].
  factory Factura.desdeXml(String texto) {
    final XmlDocument documento;
    try {
      documento = XmlDocument.parse(texto);
    } on XmlException {
      throw const InvalidResponseFailure();
    }
    final raiz = documento.rootElement;
    if (raiz.name.local != 'factura') throw const InvalidResponseFailure();

    String? dato(String ruta) {
      XmlElement? nodo = raiz;
      for (final parte in ruta.split('/')) {
        nodo = nodo?.getElement(parte);
      }
      final valor = nodo?.innerText.trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    final numero = dato('cabecera/numero');
    final fecha = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dato('cabecera/fecha') ?? '');
    final nombre = dato('cliente/nombre');
    final correo = dato('cliente/correo');
    final descripcion = dato('Detalle/producto/Nombre');
    final cantidad = int.tryParse(dato('Detalle/producto/Cantidad') ?? '');
    final unitario = Formatos.centavosDe(dato('Detalle/producto/PrecioUnitario'));
    final subtotalLinea = Formatos.centavosDe(dato('Detalle/producto/Subtotal'));
    final subtotal = Formatos.centavosDe(dato('Totales/Subtotal'));
    final porcentaje = dato('Totales/PorcentajeIVA');
    final iva = Formatos.centavosDe(dato('Totales/IVA'));
    final total = Formatos.centavosDe(dato('Totales/Total'));
    final estado = dato('Estado');

    if (numero == null ||
        fecha == null ||
        nombre == null ||
        correo == null ||
        descripcion == null ||
        cantidad == null ||
        unitario == null ||
        subtotalLinea == null ||
        subtotal == null ||
        porcentaje == null ||
        !RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(porcentaje) ||
        iva == null ||
        total == null ||
        estado == null) {
      throw const InvalidResponseFailure();
    }
    return Factura(
      numero: numero,
      fecha: DateTime(int.parse(fecha[1]!), int.parse(fecha[2]!), int.parse(fecha[3]!)),
      clienteNombre: nombre,
      clienteCorreo: correo,
      descripcion: descripcion,
      asientos: (dato('Detalle/producto/Asientos') ?? '').split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      cantidad: cantidad,
      precioUnitarioCentavos: unitario,
      subtotalCentavos: subtotal,
      ivaPorcentaje: porcentaje,
      ivaCentavos: iva,
      totalCentavos: total,
      estado: estado,
      xml: texto,
    );
  }

  final String numero;
  final DateTime fecha;
  final String clienteNombre;
  final String clienteCorreo;
  final String descripcion;
  final List<String> asientos;
  final int cantidad;
  final int precioUnitarioCentavos;
  final int subtotalCentavos;
  final String ivaPorcentaje;
  final int ivaCentavos;
  final int totalCentavos;
  final String estado;

  /// El XML tal como lo entregó el servidor (para el panel "Factura XML").
  final String xml;

  bool get anulada => estado.toLowerCase() == 'cancelada';
}
