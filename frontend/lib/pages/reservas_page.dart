import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/reservas_controller.dart';
import '../services/api_exception.dart';
import '../widgets/control_paginas.dart';
import '../widgets/estado_vista.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/tarjeta_reserva.dart';

/// "Mis reservas" (V): historial paginado del cliente.
class ReservasPage extends ConsumerWidget {
  const ReservasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(reservasControllerProvider);

    return KunturScaffold(
      seccion: Seccion.reservas,
      onRefrescar: () => ref.read(reservasControllerProvider.notifier).recargar(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const TituloCinetico('Mis reservas', estilo: AppTextStyles.titulo),
          const SizedBox(height: 4),
          const Text('Consulte, modifique o cancele sus reservas.', style: AppTextStyles.cuerpo),
          const SizedBox(height: 16),
          ..._contenido(context, ref, reservas),
        ],
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, WidgetRef ref, AsyncValue<dynamic> reservas) {
    if (reservas.isLoading && !reservas.hasValue) {
      return const [CargandoVista(tarjetas: 3)];
    }
    if (reservas.hasError && !reservas.hasValue) {
      return [
        ErrorVista(
          mensaje: mensajeDeError(reservas.error!),
          onReintentar: () => ref.invalidate(reservasControllerProvider),
        ),
      ];
    }
    final pagina = reservas.value;
    final actualizando = reservas.isLoading;
    if (pagina.reservas.isEmpty) {
      final fueraDeRango = pagina.total > 0;
      return [
        VacioVista(
          icono: Icons.confirmation_number_outlined,
          titulo: fueraDeRango ? 'Esta página ya no tiene reservas.' : 'Aún no tiene reservas.',
          mensaje: fueraDeRango ? 'Vuelva a la primera página.' : 'Busque un vuelo y reserve su asiento.',
          textoAccion: fueraDeRango ? 'Ir a la primera página' : 'Buscar vuelos',
          onAccion: () => fueraDeRango
              ? ref.read(paginaReservasProvider.notifier).primera()
              : context.go(AppRoutes.vuelos),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          pagina.total == 1 ? '1 reserva' : '${pagina.total} reservas',
          style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      Opacity(
        opacity: actualizando ? 0.5 : 1,
        child: Column(
          children: [
            for (final r in pagina.reservas)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TarjetaReserva(reserva: r, onTap: () => context.push(AppRoutes.reserva(r.id))),
              ),
          ],
        ),
      ),
      ControlPaginas(
        pagina: pagina.pagina,
        totalPaginas: pagina.totalPaginas,
        ocupado: actualizando,
        onCambiar: (n) => ref.read(paginaReservasProvider.notifier).irA(n),
      ),
    ];
  }
}
