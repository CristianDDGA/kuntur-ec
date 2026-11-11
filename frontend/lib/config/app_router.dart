import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/sesion_controller.dart';
import '../pages/estado_api_page.dart';
import '../pages/admin_page.dart';
import '../pages/crear_vuelo_page.dart';
import '../pages/login_page.dart';
import '../pages/no_encontrada_page.dart';
import '../pages/registro_page.dart';
import '../pages/reserva_detalle_page.dart';
import '../pages/reservas_page.dart';
import '../pages/seleccion_asientos_page.dart';
import '../pages/splash_page.dart';
import '../pages/vuelo_detalle_page.dart';
import '../pages/vuelos_page.dart';

/// Rutas de la aplicación. Se irán agregando por feature:
///   /reservas, /reservas/:id
class AppRoutes {
  const AppRoutes._();
  static const cargando = '/cargando';
  static const login = '/login';
  static const registro = '/registro';
  static const inicio = '/';
  static const estado = '/estado';
  static const reservas = '/reservas';
  static String reserva(int id) => '/reservas/$id';
  static String asientosDelVuelo(int id) => '/vuelos/$id/asientos';
  static String asientosDeLaReserva(int id) => '/reservas/$id/asientos';
  static const admin = '/admin';
  static const nuevoVuelo = '/admin/vuelos/nuevo';
  static String vuelo(int id) => '/vuelos/$id';

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
    errorBuilder: (_, _) => const NoEncontradaPage(),
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
      // Crear vuelos es cosa del administrador (el servidor también lo exige con 403).
      if (ruta.startsWith(AppRoutes.admin) && !sesion.value!.esAdmin) return AppRoutes.inicio;
      // El administrador no reserva: sus pantallas de reservas no existen (el servidor también responde 403).
      if (ruta.startsWith(AppRoutes.reservas) && sesion.value!.esAdmin) return AppRoutes.inicio;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.cargando, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.registro, builder: (_, _) => const RegistroPage()),
      GoRoute(path: AppRoutes.inicio, builder: (_, _) => const VuelosPage()),
      GoRoute(path: AppRoutes.reservas, builder: (_, _) => const ReservasPage()),
      GoRoute(
        path: '/reservas/:id',
        redirect: (_, state) => RegExp(r'^[1-9]\d{0,17}$').hasMatch(state.pathParameters['id'] ?? '') ? null : AppRoutes.reservas,
        builder: (_, state) => ReservaDetallePage(reservaId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'asientos',
            builder: (_, state) => SeleccionAsientosPage(reservaId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.admin, builder: (_, _) => const AdminPage()),
      GoRoute(path: AppRoutes.nuevoVuelo, builder: (_, _) => const CrearVueloPage()),
      GoRoute(
        path: '/vuelos/:id',
        // Un id que no es un entero positivo razonable ("/vuelos/abc", "/vuelos/0", 20 dígitos) vuelve a la
        // lista en vez de pedirle al servidor algo imposible. 18 dígitos = el límite de la base (BIGINT).
        redirect: (_, state) => RegExp(r'^[1-9]\d{0,17}$').hasMatch(state.pathParameters['id'] ?? '') ? null : AppRoutes.inicio,
        builder: (_, state) => VueloDetallePage(vueloId: int.parse(state.pathParameters['id']!)),
        routes: [
          // Elegir asientos es reservar: solo clientes (el administrador vuelve al detalle del vuelo).
          GoRoute(
            path: 'asientos',
            redirect: (_, state) => (ref.read(sesionControllerProvider).value?.esAdmin ?? false)
                ? AppRoutes.vuelo(int.parse(state.pathParameters['id']!))
                : null,
            builder: (_, state) => SeleccionAsientosPage(vueloId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.estado, builder: (_, _) => const EstadoApiPage()),
    ],
  );
});
