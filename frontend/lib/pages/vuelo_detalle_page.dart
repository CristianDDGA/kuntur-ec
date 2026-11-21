import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/vuelo_detalle_controller.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/etiqueta_asientos.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
import '../widgets/panel_reserva.dart';
import '../widgets/tarjeta_vuelo.dart';
import '../config/app_router.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';

/// Detalle de un vuelo (V): datos del vuelo y, para clientes, el panel para reservar.
class VueloDetallePage extends ConsumerWidget {
  const VueloDetallePage({super.key, required this.vueloId});

  final int vueloId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vuelo = ref.watch(vueloDetalleControllerProvider(vueloId));

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.vuelos,
      maxAncho: 640,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Migas([
              const Miga('Vuelos', ruta: AppRoutes.vuelos),
              Miga(vuelo.value?.codigo ?? 'Detalle del vuelo'),
            ]),
            const SizedBox(height: 12),
            vuelo.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: CargandoDetalleVista()),
              error: (error, _) => ErrorVista(
                mensaje: mensajeDeError(error),
                onReintentar: () => ref.invalidate(vueloDetalleControllerProvider(vueloId)),
              ),
              data: (v) => _Detalle(vuelo: v),
            ),
          ],
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
              FilaDetalle(icono: Icons.schedule, etiqueta: 'Duración', valor: Formatos.duracion(vuelo.duracion)),
              FilaDetalle(
                icono: Icons.event_seat_outlined,
                etiqueta: 'Asientos',
                valor: '${vuelo.asientosDisponibles} libres de ${vuelo.capacidad}',
              ),
              if (ocupados > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 8),
                  // Ocupación con relleno líquido: el chorro de pasajeros se lee de un vistazo.
                  child: BarraLiquidMorph(
                    valor: ocupados / vuelo.capacidad,
                    color: vuelo.pocosAsientos || vuelo.agotado ? AppColors.rojo : AppColors.azul,
                  ),
                ),
              FilaDetalle(
                icono: Icons.payments_outlined,
                etiqueta: 'Precio por persona',
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
