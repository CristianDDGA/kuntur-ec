import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/reservas_controller.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/barra_kuntur.dart';
import '../widgets/control_paginas.dart';
import '../widgets/tarjeta_reserva.dart';
import '../widgets/navegacion_principal.dart';

/// "Mis reservas" (V): historial paginado del cliente.
class ReservasPage extends ConsumerWidget {
  const ReservasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(reservasControllerProvider);

    return Scaffold(
      appBar: const BarraKuntur(),
      bottomNavigationBar: const NavegacionPrincipal(actual: Seccion.reservas),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(reservasControllerProvider.notifier).recargar(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  const Text('Mis reservas', style: AppTextStyles.titulo),
                  const SizedBox(height: 4),
                  const Text('Consulte, modifique o cancele sus reservas.', style: AppTextStyles.cuerpo),
                  const SizedBox(height: 16),
                  ..._contenido(context, ref, reservas),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, WidgetRef ref, AsyncValue<dynamic> reservas) {
    if (reservas.isLoading && !reservas.hasValue) {
      return const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    }
    if (reservas.hasError && !reservas.hasValue) {
      return [
        AvisoInline(texto: mensajeDeError(reservas.error!)),
        const SizedBox(height: 12),
        Align(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(reservasControllerProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }
    final pagina = reservas.value;
    final actualizando = reservas.isLoading;
    if (pagina.reservas.isEmpty) {
      final fueraDeRango = pagina.total > 0;
      return [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: AppDecorations.tarjeta,
          child: Column(
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 40, color: AppColors.textoSuave),
              const SizedBox(height: 10),
              Text(
                fueraDeRango ? 'Esta página ya no tiene reservas.' : 'Aún no tiene reservas.',
                style: AppTextStyles.subtitulo,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => fueraDeRango
                    ? ref.read(paginaReservasProvider.notifier).primera()
                    : context.go(AppRoutes.inicio),
                child: Text(fueraDeRango ? 'Ir a la primera página' : 'Buscar vuelos'),
              ),
            ],
          ),
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
