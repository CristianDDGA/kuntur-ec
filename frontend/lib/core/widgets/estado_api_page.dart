import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../di/providers.dart';

/// Pantalla temporal: verifica que el frontend se comunica con la API (/health).
/// Se reemplazará por el Login cuando se implemente la feature `auth`.
final _healthProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async => await ref.watch(apiClientProvider).get('/health') as Map<String, dynamic>,
);

class EstadoApiPage extends ConsumerWidget {
  const EstadoApiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(_healthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: health.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => _Estado(
              icon: Icons.cloud_off,
              color: Theme.of(context).colorScheme.error,
              texto: 'API no disponible\n$e',
              onRetry: () => ref.invalidate(_healthProvider),
            ),
            data: (d) => _Estado(
              icon: Icons.cloud_done,
              color: Colors.green,
              texto: 'API conectada: ${d['servicio']} (${d['estado']})',
              onRetry: () => ref.invalidate(_healthProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.icon, required this.color, required this.texto, required this.onRetry});
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
