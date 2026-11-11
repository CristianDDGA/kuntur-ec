import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/vuelo_detalle_controller.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/barra_kuntur.dart';
import '../widgets/etiqueta_asientos.dart';
import '../widgets/panel_reserva.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Detalle de un vuelo (V): datos del vuelo y, para clientes, el panel para reservar.
class VueloDetallePage extends ConsumerWidget {
  const VueloDetallePage({super.key, required this.vueloId});

  final int vueloId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vuelo = ref.watch(vueloDetalleControllerProvider(vueloId));

    return Scaffold(
      appBar: const BarraKuntur(conAtras: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: vuelo.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _Error(
                  mensaje: mensajeDeError(error),
                  onReintentar: () => ref.invalidate(vueloDetalleControllerProvider(vueloId)),
                ),
                data: (v) => _Detalle(vuelo: v),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Detalle extends ConsumerWidget {
  const _Detalle({required this.vuelo});

  final Vuelo vuelo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esAdmin = ref.watch(sesionControllerProvider).value?.esAdmin ?? false;
    final ocupados = vuelo.capacidad - vuelo.asientosDisponibles;
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
                  CodigoVuelo(vuelo.codigo),
                  const SizedBox(width: 10),
                  Expanded(child: Text(Formatos.fecha(vuelo.fecha), style: AppTextStyles.cuerpo)),
                  EtiquetaAsientos(vuelo: vuelo),
                ],
              ),
              const SizedBox(height: 20),
              RutaVuelo(vuelo: vuelo),
              const Divider(height: 36, color: AppColors.divisor),
              _Dato(icono: Icons.schedule, titulo: 'Duración', valor: Formatos.duracion(vuelo.duracion)),
              _Dato(
                icono: Icons.event_seat_outlined,
                titulo: 'Asientos',
                valor: '${vuelo.asientosDisponibles} libres de ${vuelo.capacidad}',
              ),
              if (ocupados > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ocupados / vuelo.capacidad,
                      minHeight: 8,
                      backgroundColor: AppColors.divisor,
                      color: vuelo.pocosAsientos || vuelo.agotado ? AppColors.rojo : AppColors.azul,
                    ),
                  ),
                ),
              _Dato(
                icono: Icons.payments_outlined,
                titulo: 'Precio por persona',
                valor: Formatos.dinero(vuelo.precioCentavos),
                destacado: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // El administrador gestiona vuelos pero no reserva (el servidor responde 403 si lo intentara).
        if (esAdmin)
          const AvisoInline(
            tipo: TipoAviso.info,
            texto: 'Los administradores gestionan los vuelos y no hacen reservas.',
          )
        else
          PanelReserva(vuelo: vuelo),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.titulo, required this.valor, this.destacado = false});

  final IconData icono;
  final String titulo;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icono, size: 22, color: AppColors.azul),
            const SizedBox(width: 14),
            Expanded(child: Text(titulo, style: AppTextStyles.cuerpo)),
            Text(
              valor,
              style: destacado
                  ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul)
                  : AppTextStyles.subtitulo.copyWith(fontSize: 16),
            ),
          ],
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvisoInline(texto: mensaje),
          const SizedBox(height: 12),
          Align(
            child: OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
}
