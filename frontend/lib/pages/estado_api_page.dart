import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../controllers/estado_api_controller.dart';

/// Vista (V de MVC) temporal que verifica la comunicación con la API.
/// Se reemplazará por el Login cuando se implemente la autenticación.
class EstadoApiPage extends ConsumerWidget {
  const EstadoApiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoApiControllerProvider);
    final controller = ref.read(estadoApiControllerProvider.notifier);
    final colorError = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: estado.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => _EstadoView(
              icon: Icons.cloud_off,
              color: colorError,
              texto: 'API no disponible\n$error',
              onRetry: controller.reintentar,
            ),
            data: (e) => _EstadoView(
              icon: e.disponible ? Icons.cloud_done : Icons.cloud_off,
              color: e.disponible ? Colors.green : colorError,
              texto: e.disponible ? 'API conectada: ${e.servicio}' : 'API con problemas: ${e.servicio}',
              onRetry: controller.reintentar,
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoView extends StatelessWidget {
  const _EstadoView({
    required this.icon,
    required this.color,
    required this.texto,
    required this.onRetry,
  });

  final IconData icon;
  final Color color;
  final String texto;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          const SizedBox(height: 8),
          Text(AppConfig.apiBaseUrl, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
