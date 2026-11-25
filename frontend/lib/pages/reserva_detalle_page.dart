import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/reserva_detalle_controller.dart';
import '../models/fallo.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/hoja_confirmacion.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/tarjeta_reserva.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Detalle de una reserva (V): asientos, montos tabulares y acciones de gestión.
class ReservaDetallePage extends ConsumerWidget {
  const ReservaDetallePage({super.key, required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserva = ref.watch(reservaDetalleControllerProvider(reservaId));

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.reservas,
      maxAncho: 1100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Migas([
              const Miga('Mis reservas', ruta: AppRoutes.reservas),
              Miga(Reserva.numeroDe(reservaId)),
            ]),
            const SizedBox(height: 16),
            _cuerpo(ref, reserva),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo(WidgetRef ref, AsyncValue<Reserva> reserva) {
    return reserva.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: CargandoDetalleVista()),
      error: (error, _) => ErrorVista(
        mensaje: mensajeDeError(error),
        onReintentar: () => ref.invalidate(reservaDetalleControllerProvider(reservaId)),
      ),
      data: (r) => _Contenido(reserva: r),
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.reserva});

  final Reserva reserva;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  bool _enviando = false;
  String? _error;

  ReservaDetalleController get _controlador => ref.read(reservaDetalleControllerProvider(widget.reserva.id).notifier);

  Future<void> _cancelar() async {
    final r = widget.reserva;
    final liberados = r.cantidad == 1
        ? 'el asiento ${r.asientos.join()} volverá'
        : 'los asientos ${r.asientos.join(', ')} volverán';
    final confirmado = await mostrarConfirmacionKuntur(
      context,
      titulo: '¿Cancelar la reserva?',
      mensaje: 'Se cancelará la reserva ${r.numero} (${r.vuelo.origen} → ${r.vuelo.destino}) y $liberados al vuelo. '
          'Esta acción no se puede deshacer.',
      textoConfirmar: 'Sí, cancelar',
      textoCancelar: 'No, conservarla',
      estilo: EstiloConfirmacion.destructiva,
      icono: Icons.cancel_outlined,
    );
    if (!confirmado || !mounted || _enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await _controlador.cancelar();
      if (!mounted) return;
      setState(() => _enviando = false);
      mostrarAviso(context, 'Reserva cancelada.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reserva;
    final v = r.vuelo;
    final editable = r.puedeEditarse();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.tarjeta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CodigoVuelo(v.codigo),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.numero,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitulo.copyWith(
                                  fontSize: 15,
                                  fontFeatures: AppTextStyles.tabular,
                                ),
                              ),
                              if (r.fechaReserva != null)
                                Text(
                                  'Emitida el ${Formatos.fecha(r.fechaReserva!.toLocal())}',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.nota.copyWith(fontFeatures: AppTextStyles.tabular),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    EtiquetaEstadoReserva(reserva: r),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${v.origen} → ${v.destino}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titulo.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatos.fecha(v.fecha)} · Salida ${Formatos.hora(v.horaSalida)} (llegada aprox. ${Formatos.hora(v.horaLlegada)})',
                style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular),
              ),
              const Divider(height: 32, color: AppColors.divisor),

              Text('Asientos asignados', style: AppTextStyles.subtitulo.copyWith(fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final a in r.asientos) _Asiento(a, apagado: r.cancelada)]),
              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.panelSutil,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_outlined, size: 18, color: AppColors.azul),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detalle del comprobante de venta',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.azul),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.divisor),
                    FilaDetalle(etiqueta: 'Cantidad de pasajes', valor: Formatos.entero(r.cantidad)),
                    FilaDetalle(etiqueta: 'Subtotal', valor: Formatos.dinero(r.subtotalCentavos)),
                    FilaDetalle(etiqueta: 'IVA (${Formatos.porcentaje(r.ivaPorcentaje)})', valor: Formatos.dinero(r.ivaCentavos)),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.borde),
                    const SizedBox(height: 8),
                    FilaDetalle(etiqueta: 'Total', valor: Formatos.dinero(r.totalCentavos), destacado: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, caja) {
            final verComprobante = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.azulNoche,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 48),
              ),
              onPressed: () => context.push(AppRoutes.comprobante(r.id)),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Ver comprobante (factura XML)'),
            );
            final cambiarAsientos = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48)),
              onPressed: _enviando ? null : () => context.push(AppRoutes.asientosDeLaReserva(r.id)),
              icon: const Icon(Icons.event_seat_outlined, size: 18),
              label: const Text('Cambiar asientos'),
            );
            final conEditar = editable && !r.cancelada;
            if (caja.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  verComprobante,
                  if (conEditar) ...[
                    const SizedBox(height: 10),
                    cambiarAsientos,
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: verComprobante),
                if (conEditar) ...[
                  const SizedBox(width: 12),
                  cambiarAsientos,
                ],
              ],
            );
          },
        ),
        if (r.vuelo.cancelado) ...[
          const SizedBox(height: 12),
          AvisoInline(
            texto: 'La aerolínea canceló este vuelo'
                '${r.vuelo.motivoCancelacion == null ? '' : ': ${r.vuelo.motivoCancelacion}'}. '
                'Su reserva quedó cancelada.',
          ),
        ] else if (r.cancelada) ...[
          const SizedBox(height: 12),
          const AvisoInline(tipo: TipoAviso.info, texto: 'Esta reserva fue cancelada. Los asientos volvieron al vuelo.'),
        ] else if (!editable) ...[
          const SizedBox(height: 12),
          const AvisoInline(tipo: TipoAviso.info, texto: 'Este vuelo ya partió: la reserva no se puede modificar ni cancelar.'),
        ] else ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: _enviando ? null : _cancelar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 17),
              label: const Text('Cancelar reserva'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          AvisoInline(texto: _error!),
        ],
      ],
    );
  }
}

class _Asiento extends StatelessWidget {
  const _Asiento(this.numero, {this.apagado = false});

  final String numero;
  final bool apagado;

  @override
  Widget build(BuildContext context) => MarcoIsometrico25D(
        radio: 10,
        color: apagado ? AppColors.divisor : AppColors.infoSuave,
        relleno: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          numero,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: apagado ? AppColors.textoSuave : AppColors.azul,
            decoration: apagado ? TextDecoration.lineThrough : null,
            fontFeatures: AppTextStyles.tabular,
          ),
        ),
      );
}
