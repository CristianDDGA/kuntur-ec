import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/factura.dart';
import '../services/descarga_otros.dart' if (dart.library.js_interop) '../services/descarga_web.dart';
import 'con_sesion.dart';

/// Controlador (C) del comprobante: pide el XML de la factura al servidor, lo convierte en [Factura]
/// y encapsula la descarga del archivo XML para mantener las vistas desacopladas de `services/`.
class ComprobanteController extends AsyncNotifier<Factura> {
  ComprobanteController(this.reservaId);

  final int reservaId;

  @override
  Future<Factura> build() async {
    final xml = await conSesion(ref, () => ref.read(reservaServiceProvider).comprobanteXml(reservaId));
    return Factura.desdeXml(xml);
  }

  /// Dispara la descarga del archivo `factura-<numero>.xml` en web; devuelve `false` en plataformas
  /// sin descarga directa para que la vista ofrezca el copiado al portapapeles.
  bool descargarXml(Factura factura) => descargarTexto('factura-${factura.numero}.xml', factura.xml);
}

final comprobanteControllerProvider = AsyncNotifierProvider.autoDispose.family<ComprobanteController, Factura, int>(
  ComprobanteController.new,
  retry: (_, _) => null,
);
