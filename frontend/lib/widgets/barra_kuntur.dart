import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/sesion_controller.dart';
import 'franja_tricolor.dart';
import 'logo_kuntur.dart';

/// Barra superior de las pantallas con sesión: marca, botón atrás (si [conAtras]) y cerrar sesión.
class BarraKuntur extends ConsumerWidget implements PreferredSizeWidget {
  const BarraKuntur({super.key, this.conAtras = false, this.acciones = const []});

  final bool conAtras;
  final List<Widget> acciones;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: conAtras
          ? IconButton(
              tooltip: 'Volver a los vuelos',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.inicio),
            )
          : null,
      title: const MarcaKuntur(tamanoLogo: 34, vertical: false, enOscuro: true),
      bottom: const PreferredSize(preferredSize: Size.fromHeight(5), child: FranjaTricolor()),
      actions: [
        ...acciones,
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(sesionControllerProvider.notifier).cerrarSesion(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
