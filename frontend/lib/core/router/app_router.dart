import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/estado_api_page.dart';

/// Rutas de la aplicación. Se irán agregando por feature:
///   /login, /registro, /vuelos, /vuelos/:id, /reservas, /reservas/:id, /admin/vuelos/nuevo
class AppRoutes {
  const AppRoutes._();
  static const inicio = '/';
}

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.inicio,
    routes: [
      GoRoute(path: AppRoutes.inicio, builder: (_, _) => const EstadoApiPage()),
    ],
  ),
);
