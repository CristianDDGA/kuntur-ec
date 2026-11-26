import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/estado_api_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/fallo.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vista.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
import '../widgets/migas.dart';

/// Estado del servicio de la API: comprueba la comunicación con el proveedor SOA.
class EstadoApiPage extends ConsumerWidget {
  const EstadoApiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoApiControllerProvider);
    final controller = ref.read(estadoApiControllerProvider.notifier);
    final autenticado = ref.watch(sesionControllerProvider).value != null;

    return KunturScaffold(
      conAtras: true,
      maxAncho: 800,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Migas([
            Miga(
              autenticado ? 'Vuelos' : 'Inicio',
              ruta: autenticado ? AppRoutes.vuelos : AppRoutes.inicio,
            ),
            const Miga('Estado del servicio'),
          ]),
          const SizedBox(height: 12),
          const Text('Estado del servicio', style: AppTextStyles.titulo),
          const SizedBox(height: 4),
          const Text('Comprueba si la API de Kuntur EC responde en este momento.', style: AppTextStyles.cuerpo),
          const SizedBox(height: 20),
          estado.when(
            loading: () => const CargandoDetalleVista(),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: InsigniaEstado(texto: 'API no disponible', tipo: TipoInsignia.error),
                ),
                const SizedBox(height: 12),
                const _DiagramaSoa(disponible: false),
                const SizedBox(height: 12),
                AvisoInline(texto: mensajeDeError(error)),
                const SizedBox(height: 12),
                _BotonReintentar(onPressed: controller.reintentar),
              ],
            ),
            data: (e) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InsigniaEstado(
                    texto: e.disponible ? 'API conectada' : 'API con problemas',
                    tipo: e.disponible ? TipoInsignia.exito : TipoInsignia.error,
                  ),
                ),
                const SizedBox(height: 14),
                _DiagramaSoa(disponible: e.disponible),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.tarjeta,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            e.disponible ? Icons.cloud_done : Icons.cloud_off,
                            size: 36,
                            color: e.disponible ? AppColors.exito : AppColors.error,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'API ${e.disponible ? 'conectada' : 'con problemas'}: ${e.servicio}',
                              style: AppTextStyles.subtitulo,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28, color: AppColors.divisor),
                      const Text(AppConfig.apiBaseUrl, style: AppTextStyles.nota),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _BotonReintentar(onPressed: controller.reintentar),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagrama del recorrido SOA: el cliente Flutter conectado con el proveedor Flask.
class _DiagramaSoa extends StatelessWidget {
  const _DiagramaSoa({required this.disponible});

  final bool disponible;

  @override
  Widget build(BuildContext context) {
    final color = disponible ? AppColors.exito : AppColors.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: MarcoIsometrico25D(
            radio: 14,
            relleno: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_iphone, size: 24, color: AppColors.azul),
                const SizedBox(height: 4),
                const Text('Cliente', style: AppTextStyles.etiqueta),
                Text('Flutter', style: AppTextStyles.nota.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: BarraLiquidMorph(
                  valor: disponible ? 1 : 0.3,
                  alto: 6,
                  color: color,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: color),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: MarcoIsometrico25D(
            radio: 14,
            relleno: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dns_outlined, size: 24, color: color),
                const SizedBox(height: 4),
                const Text('API', style: AppTextStyles.etiqueta),
                Text('SOA Flask', style: AppTextStyles.nota.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BotonReintentar extends StatelessWidget {
  const _BotonReintentar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
}
