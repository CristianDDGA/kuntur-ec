import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/sesion_controller.dart';

/// Secciones principales de la app.
enum Seccion { vuelos, reservas, administracion }

/// Barra de navegación inferior, siempre visible: el usuario sabe dónde está y puede ir a
/// cualquier sección con un toque, sin depender del botón "Volver".
///
/// Cliente: Vuelos · Mis reservas. Administrador: Vuelos · Administración.
class NavegacionPrincipal extends ConsumerWidget {
  const NavegacionPrincipal({super.key, required this.actual});

  /// Sección a la que pertenece la pantalla actual (se resalta).
  final Seccion actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink();

    final secciones = usuario.esAdmin
        ? const [Seccion.vuelos, Seccion.administracion]
        : const [Seccion.vuelos, Seccion.reservas];
    final indice = secciones.indexOf(actual).clamp(0, secciones.length - 1);

    return NavigationBar(
      selectedIndex: indice,
      onDestinationSelected: (i) => context.go(switch (secciones[i]) {
        Seccion.vuelos => AppRoutes.inicio,
        Seccion.reservas => AppRoutes.reservas,
        Seccion.administracion => AppRoutes.admin,
      }),
      destinations: [
        for (final s in secciones)
          switch (s) {
            Seccion.vuelos => const NavigationDestination(
                icon: Icon(Icons.flight_takeoff_outlined),
                selectedIcon: Icon(Icons.flight_takeoff),
                label: 'Vuelos',
              ),
            Seccion.reservas => const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: 'Mis reservas',
              ),
            Seccion.administracion => const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: 'Administración',
              ),
          },
      ],
    );
  }
}
