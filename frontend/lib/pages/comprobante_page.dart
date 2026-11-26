import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/comprobante_controller.dart';
import '../models/factura.dart';
import '../models/fallo.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
import '../widgets/logo_kuntur.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';

enum _Vista { factura, xml }

/// Comprobante de una reserva (V — modo lectura): factura legible y documento XML oficial.
/// Delega la descarga XML en [ComprobanteController] para cumplir MVC estricto.
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
      maxAncho: 940,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Migas([
            const Miga('Mis reservas', ruta: AppRoutes.reservas),
            Miga(
              'Reserva $numero',
              ruta: AppRoutes.reserva(widget.reservaId),
              etiquetaSemantica: 'Volver a la reserva $numero',
            ),
            const Miga('Comprobante'),
          ]),
          const SizedBox(height: 14),
          const Text('Comprobante de venta', style: AppTextStyles.titulo),
          const SizedBox(height: 4),
          const Text('Factura electrónica oficial emitida para su reserva.', style: AppTextStyles.cuerpo),
          const SizedBox(height: 18),
          if (factura.isLoading && !factura.hasValue)
            const CargandoDetalleVista()
          else if (factura.hasError && !factura.hasValue)
            ErrorVista(
              mensaje: mensajeDeError(factura.error!),
              onReintentar: () => ref.invalidate(comprobanteControllerProvider(widget.reservaId)),
            )
          else ...[
            SelectorLiquidMorph<_Vista>(
              opciones: const [
                OpcionLiquid(valor: _Vista.factura, etiqueta: 'Factura', icono: Icons.receipt_long_outlined),
                OpcionLiquid(valor: _Vista.xml, etiqueta: 'Factura XML', icono: Icons.data_object),
              ],
              seleccion: _vista,
              onCambio: (v) => setState(() => _vista = v),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppMotion.duracion(context, const Duration(milliseconds: 200)),
              reverseDuration: AppMotion.duracion(context, const Duration(milliseconds: 140)),
              switchInCurve: AppMotion.curvaSalidaFuerte,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: (actual, anteriores) => Stack(
                alignment: Alignment.topCenter,
                children: [...anteriores, if (actual != null) actual],
              ),
              child: _vista == _Vista.factura
                  ? _VistaFactura(key: const ValueKey('factura'), factura: factura.value!)
                  : _VistaXml(
                      key: const ValueKey('xml'),
                      reservaId: widget.reservaId,
                      factura: factura.value!,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Factura legible (superficie Read): tipografía tabular calma, sin movimiento decorativo.
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
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MarcaKuntur(tamanoLogo: 36, vertical: false),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InsigniaEstado(
                      texto: f.anulada ? 'Anulada' : f.estado,
                      tipo: f.anulada ? TipoInsignia.error : TipoInsignia.exito,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Factura ${f.numero}',
                  style: AppTextStyles.titulo.copyWith(fontSize: 22, fontFeatures: AppTextStyles.tabular),
                ),
                Text(
                  'Emitida el ${Formatos.fecha(f.fecha)}',
                  style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular),
                ),
                const Divider(height: 28, color: AppColors.divisor),
                const _Etiqueta('Cliente'),
                Text(f.clienteNombre, style: AppTextStyles.subtitulo.copyWith(fontSize: 16)),
                SelectableText(f.clienteCorreo, style: AppTextStyles.cuerpo),
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
                FilaDetalle(
                  etiqueta: '${f.cantidad} × ${Formatos.dinero(f.precioUnitarioCentavos)}',
                  valor: Formatos.dinero(f.subtotalCentavos),
                ),
                const SizedBox(height: 6),
                const _PerforadoConMuescas(),
                const SizedBox(height: 6),
                FilaDetalle(etiqueta: 'Subtotal', valor: Formatos.dinero(f.subtotalCentavos)),
                FilaDetalle(etiqueta: 'IVA (${Formatos.porcentaje(f.ivaPorcentaje)})', valor: Formatos.dinero(f.ivaCentavos)),
                const SizedBox(height: 6),
                FilaDetalle(
                  etiqueta: 'Total',
                  valor: Formatos.dinero(f.totalCentavos),
                  destacado: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerforadoConMuescas extends StatelessWidget {
  const _PerforadoConMuescas();

  static const double _desplazamiento = 31;
  static const double _diametro = 18;

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: _diametro,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Center(child: _Perforado()),
            Positioned(left: -_desplazamiento, top: 0, child: _Muesca(diametro: _diametro)),
            Positioned(right: -_desplazamiento, top: 0, child: _Muesca(diametro: _diametro)),
          ],
        ),
      );
}

class _Muesca extends StatelessWidget {
  const _Muesca({required this.diametro});

  final double diametro;

  @override
  Widget build(BuildContext context) => Container(
        width: diametro,
        height: diametro,
        decoration: const BoxDecoration(color: AppColors.fondo, shape: BoxShape.circle),
      );
}

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

class _VistaXml extends ConsumerStatefulWidget {
  const _VistaXml({super.key, required this.reservaId, required this.factura});

  final int reservaId;
  final Factura factura;

  @override
  ConsumerState<_VistaXml> createState() => _VistaXmlState();
}

class _VistaXmlState extends ConsumerState<_VistaXml> {
  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.factura.xml));
    if (!mounted) return;
    mostrarAviso(context, 'XML copiado al portapapeles.');
  }

  Future<void> _descargar() async {
    final nombre = 'factura-${widget.factura.numero}.xml';
    final descargado = ref
        .read(comprobanteControllerProvider(widget.reservaId).notifier)
        .descargarXml(widget.factura);
    if (descargado) {
      mostrarAviso(context, 'Descargando $nombre.');
    } else {
      await _copiar();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              const Text('Documento digital XML estructurado con firma y autorización.', style: AppTextStyles.nota),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                    onPressed: _copiar,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar XML'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    ),
                    onPressed: _descargar,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Descargar factura (XML)'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.azulNoche,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  widget.factura.xml,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.55,
                    color: Color(0xFFE6E9EE),
                  ),
                ),
              ),
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
