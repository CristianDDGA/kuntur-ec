import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/reserva_detalle_page.dart';
import 'package:vuelos_app/pages/seleccion_asientos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<RouteFakeRestClient> _abrir(WidgetTester tester, Map<String, Object?> rutas) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuarioAna},
    'GET /vuelos': respuestaVuelos,
    'GET /iva': respuestaIva,
    'GET /vuelos/3': vueloQuitoGuayaquil,
    'GET /vuelos/3/asientos': mapaJson(),
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

Future<void> _ir(WidgetTester tester, String ruta) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(ruta);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String asiento) async {
  await tester.tap(find.text(asiento));
  await tester.pump();
}

Map<String, Object?> _creada(List<String> asientos) =>
    {'mensaje': 'ok', 'reserva': reservaJson(cantidad: asientos.length, asientos: asientos)};

void main() {
  group('reservar eligiendo asientos', () {
    testWidgets('muestra el vuelo, la leyenda y el mapa con los ocupados bloqueados', (tester) async {
      await _abrir(tester, {'GET /vuelos/3/asientos': mapaJson(ocupados: ['1B'])});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));

      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
      expect(find.text('KT101'), findsWidgets); // en las migas y en la cabecera
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Seleccionado'), findsOneWidget);
      expect(find.text('Ocupado'), findsOneWidget);
      expect(find.text('1A'), findsOneWidget);
      expect(find.text('1B'), findsNothing); // el ocupado muestra una X, no su número
      expect(find.bySemanticsLabel('Asiento 1B, ocupado'), findsOneWidget);
      expect(find.bySemanticsLabel('Asiento 1A, disponible'), findsOneWidget);
    });

    testWidgets('tocar un asiento ocupado no hace nada', (tester) async {
      await _abrir(tester, {'GET /vuelos/3/asientos': mapaJson(ocupados: ['1B'])});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));

      await tester.tap(find.bySemanticsLabel('Asiento 1B, ocupado'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Asientos (0 de 10): Ninguno'), findsOneWidget);
    });

    testWidgets('al elegir asientos muestra la lista y el total con IVA, y se actualiza al cambiar', (tester) async {
      await _abrir(tester, {});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      expect(find.text('Asientos (0 de 10): Ninguno'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);

      await _tocar(tester, '1A');
      // 1 asiento: 75.50 + IVA 15 % (11.325 -> 11.33) = 86.83
      expect(find.text('Asientos (1 de 10): 1A'), findsOneWidget);
      expect(find.text(r'$86.83'), findsOneWidget);

      await _tocar(tester, '1C');
      // 2 asientos: 151.00 + 22.65 = 173.65
      expect(find.text('Asientos (2 de 10): 1A, 1C'), findsOneWidget);
      expect(find.text(r'$173.65'), findsOneWidget);

      await _tocar(tester, '1A'); // desmarcar
      expect(find.text('Asientos (1 de 10): 1C'), findsOneWidget);
      expect(find.text(r'$86.83'), findsOneWidget);
    });

    testWidgets('no deja elegir más de 10: avisa y el undécimo no se marca', (tester) async {
      await _abrir(tester, {'GET /vuelos/3/asientos': mapaJson(capacidad: 20)});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));

      for (var fila = 1; fila <= 5; fila++) {
        for (final c in ['A', 'B']) {
          await tester.scrollUntilVisible(find.text('$fila$c'), 100, scrollable: find.byType(Scrollable).first);
          await _tocar(tester, '$fila$c');
        }
      }
      expect(find.textContaining('Asientos (10 de 10)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('5C'), 100, scrollable: find.byType(Scrollable).first);
      await _tocar(tester, '5C'); // el undécimo
      expect(find.textContaining('Asientos (10 de 10)'), findsOneWidget);
      expect(find.text('Máximo 10 asientos por reserva.'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('5A'), 100, scrollable: find.byType(Scrollable).first);
      await _tocar(tester, '5A'); // quitar uno sí se puede
      expect(find.textContaining('Asientos (9 de 10)'), findsOneWidget);
    });

    testWidgets('Reiniciar selección deja todo en blanco y se desactiva', (tester) async {
      await _abrir(tester, {});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reiniciar selección')).onPressed, isNull);

      for (final a in ['1A', '1B', '1C']) {
        await _tocar(tester, a);
      }
      expect(find.text('Asientos (3 de 10): 1A, 1B, 1C'), findsOneWidget);

      await tester.tap(find.text('Reiniciar selección'));
      await tester.pump();
      expect(find.text('Asientos (0 de 10): Ninguno'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reiniciar selección')).onPressed, isNull);
    });

    testWidgets('Confirmar está desactivado sin asientos', (tester) async {
      final api = await _abrir(tester, {});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await tester.tap(find.text('Confirmar reserva'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(api.llamadas.where((l) => l.metodo == 'POST'), isEmpty);
    });

    testWidgets('confirmar envía los asientos ordenados y abre la reserva', (tester) async {
      final api = await _abrir(tester, {
        'POST /reservas': _creada(['1A', '2B']),
        'GET /reservas/58': reservaJson(asientos: ['1A', '2B']),
      });
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '2B'); // se eligen en desorden a propósito
      await _tocar(tester, '1A');

      await tester.tap(find.text('Confirmar reserva'));
      await tester.pumpAndSettle();

      expect(api.llamada('POST', '/reservas').cuerpo, {'vuelo_id': 3, 'asientos': ['1A', '2B']});
      expect(find.byType(ReservaDetallePage), findsOneWidget);
      expect(find.text('KEC-00000058'), findsWidgets);
    });

    testWidgets('doble toque rápido en Confirmar envía una sola reserva', (tester) async {
      final api = await _abrir(tester, {
        'POST /reservas': (_) => Future<Object?>.delayed(const Duration(seconds: 1), () => _creada(['1A'])),
        'GET /reservas/58': reservaJson(asientos: ['1A']),
      });
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '1A');

      await tester.tap(find.text('Confirmar reserva'));
      await tester.tap(find.text('Confirmar reserva'), warnIfMissed: false); // sin esperar ningún frame
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(api.llamadas.where((l) => l.metodo == 'POST'), hasLength(1));
    });

    testWidgets('si alguien tomó el asiento (409): avisa, lo quita de la selección y recarga el mapa', (tester) async {
      var lecturas = 0;
      final api = await _abrir(tester, {
        'GET /vuelos/3/asientos': (_) => ++lecturas == 1 ? mapaJson() : mapaJson(ocupados: ['1B']),
        'POST /reservas': const ServerFailure(
          'Uno o más asientos ya fueron reservados por otra persona. Actualice el mapa y elija de nuevo.',
          statusCode: 409,
          detalles: {'asientos_ocupados': ['1B']},
        ),
      });
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '1A');
      await _tocar(tester, '1B');

      await tester.tap(find.text('Confirmar reserva'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya fueron reservados por otra persona'), findsOneWidget);
      expect(find.text('Asientos (1 de 10): 1A'), findsOneWidget); // 1B se quitó; 1A se conserva
      expect(find.bySemanticsLabel('Asiento 1B, ocupado'), findsOneWidget); // el mapa se actualizó
      expect(api.llamadas.where((l) => l.ruta == '/vuelos/3/asientos'), hasLength(2));
      expect(find.byType(SeleccionAsientosPage), findsOneWidget);
    });

    testWidgets('Actualizar mapa quita de la selección los asientos que otro tomó mientras tanto', (tester) async {
      var lecturas = 0;
      await _abrir(tester, {'GET /vuelos/3/asientos': (_) => ++lecturas == 1 ? mapaJson() : mapaJson(ocupados: ['1A'])});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '1A');
      await _tocar(tester, '1B');

      await tester.tap(find.byTooltip('Actualizar mapa'));
      await tester.pumpAndSettle();

      expect(find.text('Asientos (1 de 10): 1B'), findsOneWidget);
    });

    testWidgets('un vuelo de 200 asientos se dibuja entero sin romperse', (tester) async {
      await _abrir(tester, {'GET /vuelos/3/asientos': mapaJson(capacidad: 200, ocupados: ['50D'])});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));

      await tester.scrollUntilVisible(find.text('50'), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Asiento 50D, ocupado'), findsOneWidget);
      expect(find.text('50C'), findsOneWidget);
    });

    testWidgets('con una capacidad que no es múltiplo de 4, la última fila queda incompleta', (tester) async {
      await _abrir(tester, {'GET /vuelos/3/asientos': mapaJson(capacidad: 10)});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await tester.scrollUntilVisible(find.text('3A'), 100, scrollable: find.byType(Scrollable).first);

      expect(find.text('3B'), findsOneWidget);
      expect(find.text('3C'), findsNothing);
      expect(find.text('3D'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si falla el mapa muestra el error y permite reintentar', (tester) async {
      var intento = 0;
      await _abrir(tester, {'GET /vuelos/3/asientos': (_) => ++intento == 1 ? throw const NetworkFailure() : mapaJson()});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('1A'), findsOneWidget);
    });

    testWidgets('un 401 al confirmar cierra la sesión y lleva al login', (tester) async {
      await _abrir(tester, {'POST /reservas': const UnauthorizedFailure()});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '1A');
      await tester.tap(find.text('Confirmar reserva'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('otro error del servidor (400 vuelo que ya partió) se muestra sin perder la selección', (tester) async {
      await _abrir(tester, {'POST /reservas': const ServerFailure('No se puede reservar un vuelo que ya partió.', statusCode: 400)});
      await _ir(tester, AppRoutes.asientosDelVuelo(3));
      await _tocar(tester, '1A');
      await tester.tap(find.text('Confirmar reserva'));
      await tester.pumpAndSettle();

      expect(find.text('No se puede reservar un vuelo que ya partió.'), findsOneWidget);
      expect(find.text('Asientos (1 de 10): 1A'), findsOneWidget);
    });
  });

  group('cambiar los asientos de una reserva', () {
    Future<RouteFakeRestClient> abrirEdicion(WidgetTester tester, Map<String, Object?> extra, {Object? reserva}) async {
      final api = await _abrir(tester, {
        'GET /reservas/58': reserva ?? reservaJson(asientos: ['1A', '1B']),
        'GET /vuelos/3/asientos': mapaJson(ocupados: ['1A', '1B', '2C']), // los 2 primeros son de esta reserva
        ...extra,
      });
      await _ir(tester, AppRoutes.asientosDeLaReserva(58));
      return api;
    }

    testWidgets('empieza con los asientos actuales elegidos y "Guardar cambios" desactivado', (tester) async {
      await abrirEdicion(tester, {});
      expect(find.text('Asientos (2 de 10): 1A, 1B'), findsOneWidget);
      expect(find.text(r'$204.70'), findsOneWidget); // 2 × 89.00 + IVA 15 % con el precio original
      final boton = find.ancestor(of: find.text('Guardar cambios'), matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(boton.first).onTap, isNull);
      expect(find.text('Restablecer'), findsOneWidget);
    });

    testWidgets('los asientos de otros siguen bloqueados; los propios se pueden soltar', (tester) async {
      await abrirEdicion(tester, {});
      expect(find.bySemanticsLabel('Asiento 2C, ocupado'), findsOneWidget);
      expect(find.bySemanticsLabel('Asiento 1A, seleccionado'), findsOneWidget);
      await _tocar(tester, '1A'); // soltar uno propio
      expect(find.text('Asientos (1 de 10): 1B'), findsOneWidget);
    });

    testWidgets('cambiar de lugar envía el conjunto final y la versión leída', (tester) async {
      final api = await abrirEdicion(tester, {
        'PUT /reservas/58': {'mensaje': 'ok', 'reserva': reservaJson(asientos: ['1A', '2A'], version: 2)},
      });
      await _tocar(tester, '1B'); // suelta 1B
      await _tocar(tester, '2A'); // toma 2A

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.llamada('PUT', '/reservas/58').cuerpo, {'asientos': ['1A', '2A'], 'version': 1});
      expect(find.byType(SeleccionAsientosPage), findsNothing); // vuelve al detalle
    });

    testWidgets('ampliar muestra el total nuevo con el IVA original', (tester) async {
      await abrirEdicion(tester, {});
      await _tocar(tester, '2A');
      // 3 × 89.00 = 267.00 + 15 % (40.05) = 307.05
      expect(find.text(r'$307.05'), findsOneWidget);
      expect(find.text('Asientos (3 de 10): 1A, 1B, 2A'), findsOneWidget);
    });

    testWidgets('Restablecer vuelve a los asientos originales', (tester) async {
      await abrirEdicion(tester, {});
      await _tocar(tester, '1A');
      await _tocar(tester, '2A');
      await _tocar(tester, '2B');
      expect(find.text('Asientos (3 de 10): 1B, 2A, 2B'), findsOneWidget);

      await tester.tap(find.text('Restablecer'));
      await tester.pump();
      expect(find.text('Asientos (2 de 10): 1A, 1B'), findsOneWidget);
    });

    testWidgets('no se puede guardar sin ningún asiento', (tester) async {
      final api = await abrirEdicion(tester, {});
      await _tocar(tester, '1A');
      await _tocar(tester, '1B');
      expect(find.text('Asientos (0 de 10): Ninguno'), findsOneWidget);
      await tester.tap(find.text('Guardar cambios'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(api.llamadas.where((l) => l.metodo == 'PUT'), isEmpty);
    });

    testWidgets('si otra persona tomó el asiento (409): avisa y lo quita', (tester) async {
      await abrirEdicion(tester, {
        'PUT /reservas/58': const ServerFailure('Uno o más asientos ya fueron reservados por otra persona.', statusCode: 409, detalles: {'asientos_ocupados': ['2A']}),
      });
      await _tocar(tester, '2A');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.textContaining('otra persona'), findsOneWidget);
      expect(find.text('Asientos (2 de 10): 1A, 1B'), findsOneWidget);
    });

    testWidgets('conflicto de versión (409): avisa y recarga la reserva', (tester) async {
      var lecturas = 0;
      await abrirEdicion(tester, {
        'GET /reservas/58': (_) => ++lecturas == 1 ? reservaJson(asientos: ['1A', '1B']) : reservaJson(asientos: ['1A'], version: 4),
        'PUT /reservas/58': const ServerFailure('Ya actualizaron este registro. Consulte la reserva y vuelva a intentarlo.', statusCode: 409),
      });
      await _tocar(tester, '2A');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ya actualizaron este registro'), findsOneWidget);
      expect(lecturas, 2);
    });

    testWidgets('una reserva cancelada o de un vuelo que ya partió no se puede editar', (tester) async {
      await abrirEdicion(tester, {}, reserva: reservaJson(estado: 'cancelada'));
      expect(find.textContaining('ya no se puede modificar'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
    });

    testWidgets('una reserva ajena (404) muestra el mensaje', (tester) async {
      await abrirEdicion(tester, {}, reserva: const ServerFailure('La reserva solicitada no existe.', statusCode: 404));
      expect(find.text('La reserva solicitada no existe.'), findsOneWidget);
    });
  });
}
