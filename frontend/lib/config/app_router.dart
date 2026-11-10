import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/sesion_controller.dart';
import '../pages/estado_api_page.dart';
import '../pages/inicio_page.dart';
import '../pages/login_page.dart';
import '../pages/registro_page.dart';
import '../pages/splash_page.dart';

/// Rutas de la aplicación. Se irán agregando por feature:
///   /vuelos, /vuelos/:id, /reservas, /reservas/:id, /admin/vuelos/nuevo
class AppRoutes {
  const AppRoutes._();
  static const cargando = '/cargando';
  static const login = '/login';
  static const registro = '/registro';
  static const inicio = '/';
  static const estado = '/estado';

  /// Se pueden ver sin haber iniciado sesión.
  static const publicas = {login, registro, estado};
}

/// El router observa la sesión y protege las rutas:
/// - mientras se valida el token guardado -> pantalla de carga;
/// - sin sesión -> solo login, registro y estado del servicio;
/// - con sesión -> login y registro redirigen al inicio.
final appRouterProvider = Provider<GoRouter>((ref) {
  final cambios = ValueNotifier<int>(0);
  ref.listen(sesionControllerProvider, (_, _) => cambios.value++);
  ref.onDispose(cambios.dispose);

  return GoRouter(
    initialLocation: AppRoutes.cargando,
    refreshListenable: cambios,
    redirect: (context, state) {
      final sesion = ref.read(sesionControllerProvider);
      final ruta = state.matchedLocation;

      if (sesion.isLoading || sesion.hasError) {
        return ruta == AppRoutes.cargando ? null : AppRoutes.cargando;
      }
      final autenticado = sesion.value != null;
      if (!autenticado) {
        return AppRoutes.publicas.contains(ruta) ? null : AppRoutes.login;
      }
      if (ruta == AppRoutes.cargando || ruta == AppRoutes.login || ruta == AppRoutes.registro) {
        return AppRoutes.inicio;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.cargando, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.registro, builder: (_, _) => const RegistroPage()),
      GoRoute(path: AppRoutes.inicio, builder: (_, _) => const InicioPage()),
      GoRoute(path: AppRoutes.estado, builder: (_, _) => const EstadoApiPage()),
    ],
  );
});
