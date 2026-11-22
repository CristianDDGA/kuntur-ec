import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/admin_page.dart';
import 'package:vuelos_app/pages/estado_api_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/reserva_detalle_page.dart';
import 'package:vuelos_app/pages/reservas_page.dart';
import 'package:vuelos_app/pages/seleccion_asientos_page.dart';
import 'package:vuelos_app/pages/vuelo_detalle_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/widgets/migas.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<RouteFakeRestClient> _abrir(WidgetTester tester, {Object usuario = usuarioAna, Map<String, Object?> rutas = const {}}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': respuestaVuelos,
    'GET /vuelos/3': vueloQuitoGuayaquil,
    'GET /vuelos/3/asientos': mapaJson(),
    'GET /iva': respuestaIva,
    'GET /reservas': paginaDeReservas(total: 1, pagina: 1),
    'GET /reservas/58': reservaJson(),
    'GET /health': healthOk,
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

Future<void> _ir(WidgetTester tester, String ruta) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(ruta);
  await tester.pumpAndSettle();
}

Finder get _barraInferior => find.byType(NavigationBar);

void main() {
  group('barra de navegación inferior', () {
    testWidgets('el cliente ve Vuelos y Mis reservas (y no Administración)', (tester) async {
      await _abrir(tester);
      expect(find.descendant(of: _barraInferior, matching: find.text('Vuelos')), findsOneWidget);
      expect(find.descendant(of: _barraInferior, matching: find.text('Mis reservas')), findsOneWidget);
      expect(find.descendant(of: _barraInferior, matching: find.text('Administración')), findsNothing);
    });

    testWidgets('el administrador ve Vuelos y Administración (y no Mis reservas)', (tester) async {
      await _abrir(tester, usuario: usuarioAdmin);
      expect(find.descendant(of: _barraInferior, matching: find.text('Vuelos')), findsOneWidget);
      expect(find.descendant(of: _barraInferior, matching: find.text('Administración')), findsOneWidget);
      expect(find.descendant(of: _barraInferior, matching: find.text('Mis reservas')), findsNothing);
    });

    testWidgets('resalta la sección en la que está el usuario', (tester) async {
      await _abrir(tester);
      expect(tester.widget<NavigationBar>(_barraInferior).selectedIndex, 0);
      await _ir(tester, AppRoutes.reserva(58));
      expect(tester.widget<NavigationBar>(_barraInferior).selectedIndex, 1); // el detalle de una reserva es de "Mis reservas"
    });

    testWidgets('desde un detalle profundo se llega a cualquier sección con un toque', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.reserva(58));
      expect(find.byType(ReservaDetallePage), findsOneWidget);

      await tester.tap(find.descendant(of: _barraInferior, matching: find.text('Vuelos')));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);

      await tester.tap(find.descendant(of: _barraInferior, matching: find.text('Mis reservas')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservasPage), findsOneWidget);
    });

    testWidgets('el administrador va a su panel desde la barra', (tester) async {
      await _abrir(tester, usuario: usuarioAdmin);
      await tester.tap(find.descendant(of: _barraInferior, matching: find.text('Administración')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPage), findsOneWidget);
    });

    testWidgets('el mapa de asientos NO tiene barra inferior (es un paso a medio camino, con su propio resumen)', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
      expect(_barraInferior, findsNothing);
    });
  });

  group('inicio desde cualquier parte', () {
    testWidgets('tocar el logo lleva al inicio', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.reserva(58));
      expect(find.byType(VuelosPage), findsNothing);

      await tester.tap(find.byTooltip('Ir al inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('también desde el mapa de asientos', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await tester.tap(find.byTooltip('Ir al inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('el botón Volver regresa a la pantalla anterior', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();
      expect(find.byType(VueloDetallePage), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });
  });

  group('migas de pan', () {
    testWidgets('en el detalle del vuelo: Vuelos › KT101, y "Vuelos" regresa', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();
      expect(find.byType(Migas), findsOneWidget);
      expect(find.descendant(of: find.byType(Migas), matching: find.text('KT101')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(Migas), matching: find.text('Vuelos')));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('en una reserva: Mis reservas › KEC-…, y "Mis reservas" regresa', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.reserva(58));
      expect(find.descendant(of: find.byType(Migas), matching: find.text('KEC-00000058')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(Migas), matching: find.text('Mis reservas')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservasPage), findsOneWidget);
    });

    testWidgets('en el mapa de asientos se puede volver al vuelo desde las migas', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await tester.tap(find.descendant(of: find.byType(Migas), matching: find.text('KT101')));
      await tester.pumpAndSettle();
      expect(find.byType(VueloDetallePage), findsOneWidget);
    });
  });

  group('menú de cuenta', () {
    testWidgets('muestra quién está conectado y su rol', (tester) async {
      await _abrir(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('ana@correo.com'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
    });

    testWidgets('el administrador figura como Administrador', (tester) async {
      await _abrir(tester, usuario: usuarioAdmin);
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Administrador'), findsOneWidget);
    });

    testWidgets('lleva al estado del servicio', (tester) async {
      await _abrir(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado del servicio'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoApiPage), findsOneWidget);
    });

    testWidgets('cerrar sesión pide confirmación: "Seguir conectado" la conserva', (tester) async {
      final api = await _abrir(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Seguir conectado'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
      expect(api.llamadas.where((l) => l.ruta == '/auth/logout'), isEmpty);
    });
  });

  group('salir del mapa de asientos con cambios', () {
    Future<void> elegir(WidgetTester tester, String asiento) async {
      await tester.tap(find.text(asiento));
      await tester.pump();
    }

    testWidgets('sin asientos elegidos, "Volver" sale sin preguntar', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionAsientosPage), findsNothing);
      expect(find.text('¿Salir sin guardar?'), findsNothing);
    });

    testWidgets('con asientos elegidos pregunta antes de salir; "Seguir eligiendo" los conserva', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await elegir(tester, '1A');

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);

      await tester.tap(find.text('Seguir eligiendo'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
      expect(find.text('Asientos (1 de 10): 1A'), findsOneWidget);
    });

    testWidgets('con asientos elegidos, "Salir" abandona la selección', (tester) async {
      await _abrir(tester);
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await elegir(tester, '1A');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionAsientosPage), findsNothing);
    });

    testWidgets('al cambiar los asientos de una reserva también avisa si hay cambios sin guardar', (tester) async {
      await _abrir(tester, rutas: {'GET /vuelos/3/asientos': mapaJson(ocupados: ['1A', '1B'])});
      await _ir(tester, AppRoutes.asientosDeLaReserva(58));
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsNothing); // sin cambios: sale directo

      await _ir(tester, AppRoutes.asientosDeLaReserva(58));
      await elegir(tester, '2A');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(find.text('Los cambios en sus asientos no se guardarán.'), findsOneWidget);
    });
  });

  testWidgets('sin sesión no hay barra de navegación ni menú (login)', (tester) async {
    final client = RouteFakeRestClient({});
    await abrirApp(tester, client: client);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(_barraInferior, findsNothing);
    expect(find.byWidgetPredicate((w) => w is PopupMenuButton), findsNothing);
  });
}
