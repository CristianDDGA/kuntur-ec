import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/comprobante_controller.dart';
import '../models/factura.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/barra_kuntur.dart';
import '../widgets/logo_kuntur.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';

enum _Vista { factura, xml }

/// Comprobante de una reserva (V): la factura legible y, en otra pestaña, el XML tal como lo entrega el servidor.
class ComprobantePage extends ConsumerStatefulWidget {
  const ComprobantePage({super.key, required this.reservaId});

  final int reservaId;

  @override
  ConsumerState<ComprobantePage> createState() => _ComprobantePageState();
}

class _ComprobantePageState extends ConsumerState<ComprobantePage> {
  _Vista _vista = _Vista.factura;

  @override
  Widget build(BuildContext context) {
    final factura = ref.watch(comprobanteControllerProvider(widget.reservaId));
    final numero = Reserva.numeroDe(widget.reservaId);

    return Scaffold(
      appBar: const BarraKuntur(conAtras: true),
      bottomNavigationBar: const NavegacionPrincipal(actual: Seccion.reservas),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Migas([
                  const Miga('Mis reservas', ruta: AppRoutes.reservas),
                  Miga(numero, ruta: AppRoutes.reserva(widget.reservaId)),
                  const Miga('Comprobante'),
                ]),
                const SizedBox(height: 10),
                const Text('Comprobante', style: AppTextStyles.titulo),
                const SizedBox(height: 4),
                const Text('La factura de su reserva, tal como la emitió el sistema.', style: AppTextStyles.cuerpo),
                const SizedBox(height: 16),
                if (factura.isLoading && !factura.hasValue)
                  const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                else if (factura.hasError && !factura.hasValue) ...[
                  AvisoInline(texto: mensajeDeError(factura.error!)),
                  const SizedBox(height: 12),
                  Align(
                    child: OutlinedButton.icon(
                      onPressed: () => ref.invalidate(comprobanteControllerProvider(widget.reservaId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ] else ...[
                  SegmentedButton<_Vista>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _Vista.factura, icon: Icon(Icons.receipt_long_outlined), label: Text('Factura')),
                      ButtonSegment(value: _Vista.xml, icon: Icon(Icons.code), label: Text('Factura XML')),
                    ],
                    selected: {_vista},
                    onSelectionChanged: (v) => setState(() => _vista = v.first),
                  ),
                  const SizedBox(height: 16),
                  if (_vista == _Vista.factura) _VistaFactura(factura: factura.value!) else _VistaXml(factura: factura.value!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VistaFactura extends StatelessWidget {
  const _VistaFactura({required this.factura});

  final Factura factura;

  @override
  Widget build(BuildContext context) {
    final f = factura;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MarcaKuntur(tamanoLogo: 36, vertical: false),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: f.anulada ? AppColors.errorSuave : AppColors.exitoSuave,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.anulada ? 'Anulada' : f.estado,
                  style: TextStyle(
                    color: f.anulada ? AppColors.error : AppColors.exito,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Factura ${f.numero}', style: AppTextStyles.titulo.copyWith(fontSize: 22)),
          Text('Emitida el ${Formatos.fecha(f.fecha)}', style: AppTextStyles.cuerpo),
          const Divider(height: 28, color: AppColors.divisor),
          const _Etiqueta('Cliente'),
          Text(f.clienteNombre, style: AppTextStyles.subtitulo.copyWith(fontSize: 16)),
          Text(f.clienteCorreo, style: AppTextStyles.cuerpo),
          const Divider(height: 28, color: AppColors.divisor),
          const _Etiqueta('Detalle'),
          Text(f.descripcion, style: AppTextStyles.subtitulo.copyWith(fontSize: 15)),
          if (f.asientos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in f.asientos)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.infoSuave, borderRadius: BorderRadius.circular(8)),
                    child: Text('Asiento $a', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 12.5)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _Linea('${f.cantidad} × ${Formatos.dinero(f.precioUnitarioCentavos)}', Formatos.dinero(f.subtotalCentavos)),
          const Divider(height: 28, color: AppColors.divisor),
          _Linea('Subtotal', Formatos.dinero(f.subtotalCentavos)),
          _Linea('IVA (${Formatos.porcentaje(f.ivaPorcentaje)})', Formatos.dinero(f.ivaCentavos)),
          const SizedBox(height: 6),
          _Linea('Total', Formatos.dinero(f.totalCentavos), destacado: true),
        ],
      ),
    );
  }
}

class _VistaXml extends StatelessWidget {
  const _VistaXml({required this.factura});

  final Factura factura;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Así lo entrega el servidor (application/xml).', style: AppTextStyles.nota),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: factura.xml));
                if (context.mounted) mostrarAviso(context, 'XML copiado al portapapeles.');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar XML'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.azulNoche,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            factura.xml,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5, color: Color(0xFFE6E9EE)),
          ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(texto.toUpperCase(), style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor, {this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: destacado ? AppTextStyles.subtitulo.copyWith(fontSize: 16) : AppTextStyles.cuerpo)),
            Text(
              valor,
              style: destacado
                  ? const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.azul)
                  : AppTextStyles.subtitulo.copyWith(fontSize: 15),
            ),
          ],
        ),
      );
}
