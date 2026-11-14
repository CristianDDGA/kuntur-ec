import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/comprobante_controller.dart';
import '../models/factura.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/kuntur_scaffold.dart';
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

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.reservas,
      maxAncho: 640,
      body: ListView(
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
            const CargandoDetalleVista()
          else if (factura.hasError && !factura.hasValue)
            ErrorVista(
              mensaje: mensajeDeError(factura.error!),
              onReintentar: () => ref.invalidate(comprobanteControllerProvider(widget.reservaId)),
            )
          else ...[
            SegmentedButton<_Vista>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Vista.factura, label: Text('Factura')),
                ButtonSegment(value: _Vista.xml, label: Text('Factura XML')),
              ],
              selected: {_vista},
              onSelectionChanged: (v) => setState(() => _vista = v.first),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppMotion.mediaDe(context),
              switchInCurve: AppMotion.curvaEntrada,
              child: _vista == _Vista.factura
                  ? _VistaFactura(key: const ValueKey('factura'), factura: factura.value!)
                  : _VistaXml(key: const ValueKey('xml'), factura: factura.value!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Factura legible con estética de comprobante: franja de marca, datos y perforación antes de los totales.
class _VistaFactura extends StatelessWidget {
  const _VistaFactura({super.key, required this.factura});

  final Factura factura;

  @override
  Widget build(BuildContext context) {
    final f = factura;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FranjaTricolor(alto: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MarcaKuntur(tamanoLogo: 36, vertical: false),
                    const Spacer(),
                    InsigniaEstado(
                      texto: f.anulada ? 'Anulada' : f.estado,
                      tipo: f.anulada ? TipoInsignia.error : TipoInsignia.exito,
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
                        InsigniaEstado(texto: 'Asiento $a', tipo: TipoInsignia.info),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                FilaDetalle(etiqueta: '${f.cantidad} × ${Formatos.dinero(f.precioUnitarioCentavos)}', valor: Formatos.dinero(f.subtotalCentavos)),
                const SizedBox(height: 6),
                const _Perforado(),
                const SizedBox(height: 6),
                FilaDetalle(etiqueta: 'Subtotal', valor: Formatos.dinero(f.subtotalCentavos)),
                FilaDetalle(etiqueta: 'IVA (${Formatos.porcentaje(f.ivaPorcentaje)})', valor: Formatos.dinero(f.ivaCentavos)),
                const SizedBox(height: 6),
                FilaDetalle(etiqueta: 'Total', valor: Formatos.dinero(f.totalCentavos), destacado: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea discontinua que separa los datos del pago, como en un comprobante impreso.
class _Perforado extends StatelessWidget {
  const _Perforado();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, caja) {
          final tramos = (caja.maxWidth / 14).floor().clamp(1, 200);
          return Row(
            children: [
              for (var i = 0; i < tramos; i++)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: AppColors.borde,
                  ),
                ),
            ],
          );
        },
      );
}

class _VistaXml extends StatefulWidget {
  const _VistaXml({super.key, required this.factura});

  final Factura factura;

  @override
  State<_VistaXml> createState() => _VistaXmlState();
}

class _VistaXmlState extends State<_VistaXml> {
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.factura.xml));
    if (!mounted) return;
    setState(() => _copiado = true);
    mostrarAviso(context, 'XML copiado al portapapeles.');
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Así lo entrega el servidor (application/xml).', style: AppTextStyles.nota),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _copiar,
                icon: AnimatedSwitcher(
                  duration: AppMotion.rapidaDe(context),
                  child: Icon(_copiado ? Icons.check : Icons.copy, key: ValueKey(_copiado), size: 18),
                ),
                label: Text(_copiado ? 'Copiado' : 'Copiar XML'),
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
              widget.factura.xml,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5, color: Color(0xFFE6E9EE)),
            ),
          ),
        ],
      );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          texto.toUpperCase(),
          style: AppTextStyles.etiqueta.copyWith(letterSpacing: 0.8),
        ),
      );
}
