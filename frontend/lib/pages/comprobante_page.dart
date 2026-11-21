import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/comprobante_controller.dart';
import '../models/factura.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../services/descarga_otros.dart' if (dart.library.js_interop) '../services/descarga_web.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
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
      maxAncho: 1000,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Migas([
            const Miga('Mis reservas', ruta: AppRoutes.reservas),
            Miga(numero, ruta: AppRoutes.reserva(widget.reservaId)),
            const Miga('Comprobante'),
          ]),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comprobante de venta', style: AppTextStyles.titulo),
                    SizedBox(height: 4),
                    Text('Factura electrónica oficial emitida para su reserva.', style: AppTextStyles.cuerpo),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azul,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.go(AppRoutes.reserva(widget.reservaId)),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Volver a reserva', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                const _PerforadoConMuescas(),
                const SizedBox(height: 6),
                FilaDetalle(etiqueta: 'Subtotal', valor: Formatos.dinero(f.subtotalCentavos)),
                FilaDetalle(etiqueta: 'IVA (${Formatos.porcentaje(f.ivaPorcentaje)})', valor: Formatos.dinero(f.ivaCentavos)),
                const SizedBox(height: 6),
                // El total se anima con el odómetro cinético (un único `Text` conserva `find.text`).
                Semantics(
                  label: 'Total: ${Formatos.dinero(f.totalCentavos)}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Total', style: AppTextStyles.cuerpo)),
                        const SizedBox(width: 12),
                        OdometroCinetico(
                          texto: Formatos.dinero(f.totalCentavos),
                          estilo: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textoPrincipal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea discontinua de perforado con las muescas semicirculares laterales
/// propias de un *boarding pass*: dos círculos del color del fondo recortan el
/// borde de la tarjeta a la altura de la perforación.
class _PerforadoConMuescas extends StatelessWidget {
  const _PerforadoConMuescas();

  /// El contenido de la factura lleva 22 pt de relleno lateral: el centro de la
  /// muesca queda justo sobre el borde de la tarjeta (22 + 9 = 31).
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
            Positioned(
              left: -_desplazamiento,
              top: 0,
              child: _Muesca(diametro: _diametro),
            ),
            Positioned(
              right: -_desplazamiento,
              top: 0,
              child: _Muesca(diametro: _diametro),
            ),
          ],
        ),
      );
}

/// Semicírculo del color del fondo que simula el corte del troquel.
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
  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.factura.xml));
    if (!mounted) return;
    mostrarAviso(context, 'XML copiado al portapapeles.');
  }

  Future<void> _descargar() async {
    final nombre = 'factura-${widget.factura.numero}.xml';
    if (descargarTexto(nombre, widget.factura.xml)) {
      mostrarAviso(context, 'Descargando $nombre.');
    } else {
      await _copiar(); // fuera de la web no hay descarga directa
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text('Documento digital XML estructurado con firma y autorización.', style: AppTextStyles.nota),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azul,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _copiar,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar XML', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _descargar,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Descargar factura (XML)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
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
