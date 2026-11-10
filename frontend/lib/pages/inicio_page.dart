import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../models/usuario.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/logo_kuntur.dart';

/// Pantalla a la que se llega al iniciar sesión.
/// En la siguiente etapa (F2) mostrará aquí la búsqueda de vuelos.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink(); // el router ya está redirigiendo al login

    return Scaffold(
      appBar: AppBar(
        title: const MarcaKuntur(tamanoLogo: 34, vertical: false, enOscuro: true),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(5), child: FranjaTricolor()),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sesionControllerProvider.notifier).cerrarSesion(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TarjetaUsuario(usuario: usuario),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.tarjeta,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Su sesión está activa', style: AppTextStyles.subtitulo),
                        const SizedBox(height: 6),
                        const Text(
                          'En la siguiente etapa verá aquí los vuelos disponibles y podrá reservar.',
                          style: AppTextStyles.cuerpo,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.estado),
                          icon: const Icon(Icons.cloud_done_outlined),
                          label: const Text('Ver estado del servicio'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.tarjeta,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.azul,
              child: Text(
                usuario.iniciales,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${usuario.nombre}', style: AppTextStyles.subtitulo),
                  const SizedBox(height: 2),
                  Text(usuario.correo, style: AppTextStyles.cuerpo),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(usuario.esAdmin ? 'Administrador' : 'Cliente'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: usuario.esAdmin ? AppColors.avisoSuave : AppColors.infoSuave,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
