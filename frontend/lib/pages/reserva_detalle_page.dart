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
import '../widgets/barra_kuntur.dart';
import '../widgets/tarjeta_reserva.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Detalle de una reserva (V): asientos, montos y las acciones de cambiar asientos o cancelar.
class ReservaDetallePage extends ConsumerWidget {
  const ReservaDetallePage({super.key, required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserva = ref.watch(reservaDetalleControllerProvider(reservaId));

    return Scaffold(
      appBar: const BarraKuntur(conAtras: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: reserva.when(
                loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AvisoInline(texto: mensajeDeError(error)),
                    const SizedBox(height: 12),
                    Align(
                      child: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(reservaDetalleControllerProvider(reservaId)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  ],
                ),
                data: (r) => _Contenido(reserva: r),
              ),
            ),
          ),
        ),
      ),
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
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: Text(
          'Se cancelará la reserva ${r.numero} (${r.vuelo.origen} → ${r.vuelo.destino}) y $liberados al vuelo. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, conservarla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted || _enviando) return;
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
          padding: const EdgeInsets.all(22),
          decoration: AppDecorations.tarjeta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CodigoVuelo(v.codigo),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.numero, style: AppTextStyles.nota)),
                  EtiquetaEstadoReserva(reserva: r),
                ],
              ),
              const SizedBox(height: 16),
              Text('${v.origen} → ${v.destino}', style: AppTextStyles.titulo.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                '${Formatos.fecha(v.fecha)} · sale ${Formatos.hora(v.horaSalida)}, llega ${Formatos.hora(v.horaLlegada)}',
                style: AppTextStyles.cuerpo,
              ),
              const Divider(height: 32, color: AppColors.divisor),
              const Text('Asientos', style: AppTextStyles.cuerpo),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final a in r.asientos) _Asiento(a, apagado: r.cancelada)]),
              const SizedBox(height: 12),
              _Fila('Cantidad', '${r.cantidad}'),
              _Fila('Subtotal', Formatos.dinero(r.subtotalCentavos)),
              _Fila('IVA (${Formatos.porcentaje(r.ivaPorcentaje)})', Formatos.dinero(r.ivaCentavos)),
              const SizedBox(height: 4),
              _Fila('Total', Formatos.dinero(r.totalCentavos), destacado: true),
              if (r.fechaReserva != null) ...[
                const SizedBox(height: 8),
                Text('Reservada el ${Formatos.fecha(r.fechaReserva!.toLocal())}', style: AppTextStyles.nota),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (r.cancelada)
          const AvisoInline(tipo: TipoAviso.info, texto: 'Esta reserva fue cancelada. Los asientos volvieron al vuelo.')
        else if (!editable)
          const AvisoInline(tipo: TipoAviso.info, texto: 'Este vuelo ya partió: la reserva no se puede modificar ni cancelar.')
        else ...[
          OutlinedButton.icon(
            onPressed: _enviando ? null : () => context.push(AppRoutes.asientosDeLaReserva(r.id)),
            icon: const Icon(Icons.event_seat_outlined),
            label: const Text('Cambiar asientos'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            onPressed: _enviando ? null : _cancelar,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar reserva'),
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

/// Un asiento de la reserva ("1A") en una pastilla.
class _Asiento extends StatelessWidget {
  const _Asiento(this.numero, {this.apagado = false});

  final String numero;
  final bool apagado;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: apagado ? AppColors.divisor : AppColors.infoSuave,
          borderRadius: BorderRadius.circular(10),
        ),
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

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor, {this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(etiqueta, style: destacado ? AppTextStyles.subtitulo.copyWith(fontSize: 16) : AppTextStyles.cuerpo),
            ),
            Text(
              valor,
              style: destacado
                  ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul)
                  : AppTextStyles.subtitulo.copyWith(fontSize: 15),
            ),
          ],
        ),
      );
}
