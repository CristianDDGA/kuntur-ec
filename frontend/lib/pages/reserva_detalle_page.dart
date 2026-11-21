import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/reserva_detalle_controller.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
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

/// Detalle de una reserva (V): asientos, montos y las acciones de cambiar asientos o cancelar.
class ReservaDetallePage extends ConsumerWidget {
  const ReservaDetallePage({super.key, required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserva = ref.watch(reservaDetalleControllerProvider(reservaId));

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.reservas,
      maxAncho: 880,
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
    final liberados = r.cantidad == 1 ? 'el asiento ${r.asientos.join()} volverá' : 'los asientos ${r.asientos.join(', ')} volverán';
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
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CodigoVuelo(v.codigo),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.numero, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B))),
                      if (r.fechaReserva != null)
                        Text(
                          'Emitida el ${Formatos.fecha(r.fechaReserva!.toLocal())}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  EtiquetaEstadoReserva(reserva: r),
                ],
              ),
              const SizedBox(height: 20),
              Text('${v.origen} → ${v.destino}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(
                '${Formatos.fecha(v.fecha)} · Salida ${Formatos.hora(v.horaSalida)} (llegada aprox. ${Formatos.hora(v.horaLlegada)})',
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
              const Divider(height: 36, color: Color(0xFFF1F5F9)),

              // Asientos
              const Text('Asientos asignados', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final a in r.asientos) _Asiento(a, apagado: r.cancelada)]),
              const SizedBox(height: 24),

              // Detalle de la factura / montos
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_outlined, size: 18, color: AppColors.azul),
                        SizedBox(width: 8),
                        Text('Detalle del comprobante de venta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.azul)),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    FilaDetalle(etiqueta: 'Cantidad de pasajes', valor: '${r.cantidad}'),
                    FilaDetalle(etiqueta: 'Subtotal', valor: Formatos.dinero(r.subtotalCentavos)),
                    FilaDetalle(etiqueta: 'IVA (${Formatos.porcentaje(r.ivaPorcentaje)})', valor: Formatos.dinero(r.ivaCentavos)),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 8),
                    FilaDetalle(etiqueta: 'Total', valor: Formatos.dinero(r.totalCentavos), destacado: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azulNoche,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push(AppRoutes.comprobante(r.id)),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Ver comprobante (factura XML)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            if (editable && !r.cancelada) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azul,
                  side: const BorderSide(color: AppColors.azul, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _enviando ? null : () => context.push(AppRoutes.asientosDeLaReserva(r.id)),
                icon: const Icon(Icons.event_seat_outlined, size: 18),
                label: const Text('Cambiar asientos', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        if (r.cancelada) ...[
          const SizedBox(height: 12),
          const AvisoInline(tipo: TipoAviso.info, texto: 'Esta reserva fue cancelada. Los asientos volvieron al vuelo.'),
        ] else if (!editable) ...[
          const SizedBox(height: 12),
          const AvisoInline(tipo: TipoAviso.info, texto: 'Este vuelo ya partió: la reserva no se puede modificar ni cancelar.'),
        ] else ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _enviando ? null : _cancelar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancelar reserva', style: TextStyle(fontWeight: FontWeight.w700)),
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

/// Un asiento de la reserva ("1A") en una pastilla con relieve isométrico 2.5D,
/// igual que las butacas de la cabina. Al cancelar conserva el texto tachado.
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
          ),
        ),
      );
}
