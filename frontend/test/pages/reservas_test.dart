import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/reserva_detalle_page.dart';
import 'package:vuelos_app/pages/reservas_page.dart';
import 'package:vuelos_app/pages/seleccion_asientos_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<RouteFakeRestClient> _abrir(WidgetTester tester, Map<String, Object?> rutas, {Object usuario = usuarioAna}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': respuestaVuelos,
    'GET /iva': respuestaIva,
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

void _irA(WidgetTester tester, String ruta) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(ruta);

Future<void> _abajo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  group('desde el detalle del vuelo', () {
    testWidgets('invita a elegir asientos y abre el mapa', (tester) async {
      await _abrir(tester, {'GET /vuelos/3': vueloQuitoGuayaquil, 'GET /vuelos/3/asientos': mapaJson()});
      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();

      expect(find.text('Reservar este vuelo'), findsOneWidget);
      expect(find.textContaining('hasta 10 por reserva'), findsOneWidget);

      await tester.tap(find.text('Elegir asientos'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
    });

    testWidgets('vuelo agotado: no hay botón para elegir asientos', (tester) async {
      await _abrir(tester, {'GET /vuelos/3': {...vueloQuitoGuayaquil, 'asientos_disponibles': 0}});
      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir asientos'), findsNothing);
      expect(find.text('Este vuelo ya no tiene asientos disponibles.'), findsOneWidget);
    });

    testWidgets('el administrador no ve el botón ni el acceso a Mis reservas', (tester) async {
      await _abrir(tester, {'GET /vuelos/3': vueloQuitoGuayaquil}, usuario: usuarioAdmin);
      expect(find.byTooltip('Mis reservas'), findsNothing);
      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir asientos'), findsNothing);
      expect(find.text('Los administradores gestionan los vuelos y no hacen reservas.'), findsOneWidget);
    });

    testWidgets('el administrador que escribe /reservas o el mapa de asientos vuelve atrás', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos/3': vueloQuitoGuayaquil}, usuario: usuarioAdmin);
      for (final ruta in ['/reservas', '/reservas/58', '/reservas/58/asientos']) {
        _irA(tester, ruta);
        await tester.pumpAndSettle();
        expect(find.byType(VuelosPage), findsOneWidget, reason: ruta);
      }
      _irA(tester, '/vuelos/3/asientos');
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionAsientosPage), findsNothing); // vuelve al detalle del vuelo
      expect(api.rutasSolicitadas.where((r) => r.contains('/reservas') || r.contains('/asientos')), isEmpty);
    });
  });

  group('mis reservas', () {
    testWidgets('lista las reservas con ruta, asientos, total y estado', (tester) async {
      await _abrir(tester, {
        'GET /reservas': {
          ...paginaDeReservas(total: 2, pagina: 1),
          'reservas': [reservaJson(), reservaJson(id: 59, estado: 'cancelada', cantidad: 1, total: '102.35')],
        },
      });
      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();

      expect(find.byType(ReservasPage), findsOneWidget);
      expect(find.text('2 reservas'), findsOneWidget);
      expect(find.text('Quito → Guayaquil'), findsNWidgets(2));
      expect(find.text(r'$204.70'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('1 asiento'), findsOneWidget);
    });

    testWidgets('sin reservas invita a buscar vuelos', (tester) async {
      await _abrir(tester, {'GET /reservas': sinReservas});
      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tiene reservas.'), findsOneWidget);

      await tester.tap(find.text('Buscar vuelos').last);
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('con 25 reservas hay 3 páginas y se navega', (tester) async {
      late final RouteFakeRestClient client;
      client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': respuestaVuelos,
        'GET /iva': respuestaIva,
        'GET /reservas': (_) => paginaDeReservas(
              total: 25,
              pagina: int.parse(client.llamadas.lastWhere((l) => l.ruta == '/reservas').consulta!['pagina']!),
            ),
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();

      expect(find.text('25 reservas'), findsOneWidget);
      await _abajo(tester, find.byTooltip('Página siguiente'));
      expect(find.text('Página 1 de 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      await _abajo(tester, find.byTooltip('Página siguiente'));
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(client.llamadas.where((l) => l.ruta == '/reservas').last.consulta!['pagina'], '2');
    });

    testWidgets('si falla la carga ofrece reintentar', (tester) async {
      var intento = 0;
      await _abrir(tester, {'GET /reservas': (_) => ++intento == 1 ? throw const NetworkFailure() : paginaDeReservas(total: 1, pagina: 1)});
      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('1 reserva'), findsOneWidget);
    });
  });

  group('detalle de una reserva', () {
    Future<RouteFakeRestClient> abrirDetalle(WidgetTester tester, Map<String, Object?> extra, {Object? reserva}) async {
      final api = await _abrir(tester, {'GET /reservas/58': reserva ?? reservaJson(), ...extra});
      _irA(tester, AppRoutes.reserva(58));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('muestra vuelo, asientos, montos y las acciones', (tester) async {
      await abrirDetalle(tester, {});
      expect(find.text('Quito → Guayaquil'), findsOneWidget);
      expect(find.text('1A'), findsOneWidget);
      expect(find.text('1B'), findsOneWidget);
      expect(find.text(r'$178.00'), findsOneWidget);
      expect(find.text('IVA (15 %)'), findsOneWidget);
      expect(find.text(r'$204.70'), findsOneWidget);
      expect(find.text('Cambiar asientos'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);
    });

    testWidgets('"Cambiar asientos" abre el mapa con los asientos actuales marcados', (tester) async {
      await abrirDetalle(tester, {'GET /vuelos/3': vueloQuitoGuayaquil, 'GET /vuelos/3/asientos': mapaJson(ocupados: ['1A', '1B', '2C'])});
      await tester.tap(find.text('Cambiar asientos'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
      expect(find.text('Asientos (2 de 10): 1A, 1B'), findsOneWidget); // los suyos aparecen elegidos
      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets('cancelar pide confirmación y no envía nada si se arrepiente', (tester) async {
      final api = await abrirDetalle(tester, {});
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar la reserva?'), findsOneWidget);
      expect(find.textContaining('1A, 1B'), findsWidgets); // dice qué asientos se liberan

      await tester.tap(find.text('No, conservarla'));
      await tester.pumpAndSettle();
      expect(api.llamadas.where((l) => l.metodo == 'DELETE'), isEmpty);
    });

    testWidgets('cancelar confirmado: envía DELETE y la reserva queda cancelada sin acciones', (tester) async {
      final api = await abrirDetalle(tester, {
        'DELETE /reservas/58': {'mensaje': 'ok', 'reserva': reservaJson(estado: 'cancelada', version: 2)},
      });
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(api.llamadas.where((l) => l.metodo == 'DELETE'), hasLength(1));
      expect(find.text('Cancelada'), findsWidgets);
      expect(find.text('Cambiar asientos'), findsNothing);
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.textContaining('fue cancelada'), findsOneWidget);
      expect(find.text('1A'), findsOneWidget); // los asientos siguen en el historial
    });

    testWidgets('una reserva ya cancelada no ofrece acciones', (tester) async {
      await abrirDetalle(tester, {}, reserva: reservaJson(estado: 'cancelada'));
      expect(find.text('Cambiar asientos'), findsNothing);
      expect(find.text('Cancelar reserva'), findsNothing);
    });

    testWidgets('si el vuelo ya partió no se puede modificar ni cancelar', (tester) async {
      await abrirDetalle(tester, {}, reserva: reservaJson(fecha: '2020-01-01'));
      expect(find.text('Cambiar asientos'), findsNothing);
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.textContaining('ya partió'), findsOneWidget);
      expect(find.text('Vuelo realizado'), findsOneWidget);
    });

    testWidgets('reserva ajena o inexistente (404): muestra el mensaje y permite reintentar', (tester) async {
      await abrirDetalle(tester, {}, reserva: const ServerFailure('La reserva solicitada no existe.', statusCode: 404));
      expect(find.text('La reserva solicitada no existe.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('ids absurdos en la URL vuelven al historial sin llamar al servidor', (tester) async {
      final api = await _abrir(tester, {'GET /reservas': sinReservas});
      for (final id in ['0', 'abc', '99999999999999999999', '-1', '1.5']) {
        _irA(tester, '/reservas/$id');
        await tester.pumpAndSettle();
        expect(find.byType(ReservasPage), findsOneWidget, reason: id);
      }
      expect(api.rutasSolicitadas.where((r) => r.startsWith('GET /reservas/')), isEmpty);
    });

    testWidgets('el detalle de una reserva ya no muestra la edición en línea de la cantidad', (tester) async {
      await abrirDetalle(tester, {});
      expect(find.byType(ReservaDetallePage), findsOneWidget);
      expect(find.byTooltip('Más asientos'), findsNothing);
    });
  });
}
