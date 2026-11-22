import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/factura.dart';
import 'con_sesion.dart';

/// Controlador (C) del comprobante: pide el XML de la factura al servidor y lo convierte en un [Factura].
/// Un estado por reserva; se descarta al salir de la pantalla.
class ComprobanteController extends AsyncNotifier<Factura> {
  ComprobanteController(this.reservaId);

  final int reservaId;

  @override
  Future<Factura> build() async {
    final xml = await conSesion(ref, () => ref.read(reservaServiceProvider).comprobanteXml(reservaId));
    return Factura.desdeXml(xml);
  }
}

final comprobanteControllerProvider = AsyncNotifierProvider.autoDispose.family<ComprobanteController, Factura, int>(
  ComprobanteController.new,
  retry: (_, _) => null,
);
