import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/pages/crear_vuelo_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/vuelo_detalle_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

/// Abre la app ya autenticada como [usuario].
Future<RouteFakeRestClient> _abrir(
  WidgetTester tester,
  Map<String, Object?> rutas, {
  Object usuario = usuarioAna,
}) async {
  final client = RouteFakeRestClient({'GET /auth/perfil': {'usuario': usuario}, ...rutas});
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

void main() {
  group('lista de vuelos', () {
    testWidgets('muestra los vuelos con ruta, horario, precio y disponibilidad', (tester) async {
      await _abrir(tester, {'GET /vuelos': respuestaVuelos});

      expect(find.text('2 vuelos disponibles'), findsOneWidget);
      expect(find.text('KT101'), findsOneWidget);
      expect(find.text('KT202'), findsOneWidget);
      expect(find.text(r'$75.50'), findsOneWidget);
      expect(find.text('42 asientos'), findsOneWidget);
      expect(find.text('Quedan 3'), findsOneWidget); // pocos asientos
      expect(find.text('23:30'), findsOneWidget);
      expect(find.text('00:25'), findsOneWidget); // llegada después de medianoche
    });

    testWidgets('al entrar no envía filtros', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': respuestaVuelos});
      expect(api.llamada('GET', '/vuelos').consulta, {'pagina': '1', 'por_pagina': '10'});
    });

    testWidgets('buscar envía origen y destino sin espacios sobrantes', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': respuestaVuelos});

      await escribir(tester, 'Origen', '  Quito ');
      await escribir(tester, 'Destino', 'Guayaquil');
      await tocarBoton(tester, 'Buscar vuelos');
      await tester.pumpAndSettle();

      final busquedas = api.llamadas.where((l) => l.ruta == '/vuelos').toList();
      expect(busquedas, hasLength(2));
      expect(busquedas.last.consulta, {'origen': 'Quito', 'destino': 'Guayaquil', 'pagina': '1', 'por_pagina': '10'});
    });

    testWidgets('en los filtros no se pueden escribir números, símbolos ni emojis', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': respuestaVuelos});

      await escribir(tester, 'Origen', 'Qu1to 😀<>');
      await tocarBoton(tester, 'Buscar vuelos');
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(campo('Origen')).controller!.text, 'Quto');
      expect(api.llamadas.where((l) => l.ruta == '/vuelos').last.consulta?['origen'], 'Quto');
    });

    testWidgets('limpiar quita los filtros y vuelve a pedir todos los vuelos', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': respuestaVuelos});

      await escribir(tester, 'Origen', 'Quito');
      await tocarBoton(tester, 'Buscar vuelos');
      await tester.pumpAndSettle();
      await tocarBoton(tester, 'Limpiar');
      await tester.pumpAndSettle();

      expect(api.llamadas.where((l) => l.ruta == '/vuelos').last.consulta, {'pagina': '1', 'por_pagina': '10'});
      expect(tester.widget<TextFormField>(campo('Origen')).controller!.text, isEmpty);
    });

    testWidgets('sin resultados con filtros explica qué hacer', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos});
      expect(find.text('No hay vuelos programados.'), findsOneWidget);

      await escribir(tester, 'Origen', 'Loja');
      await tocarBoton(tester, 'Buscar vuelos');
      await tester.pumpAndSettle();

      expect(find.text('No encontramos vuelos con esos datos.'), findsOneWidget);
    });

    testWidgets('si falla la carga muestra el error y permite reintentar', (tester) async {
      var intento = 0;
      await _abrir(tester, {
        'GET /vuelos': (_) => ++intento == 1 ? throw const NetworkFailure() : respuestaVuelos,
      });
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

      await tocarBoton(tester, 'Reintentar');
      await tester.pumpAndSettle();

      expect(find.text('KT101'), findsOneWidget);
      expect(find.text('No se pudo conectar con el servidor.'), findsNothing);
    });

    testWidgets('un 401 cierra la sesión y lleva al login', (tester) async {
      await _abrir(tester, {'GET /vuelos': const UnauthorizedFailure()});
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('el cliente no ve el botón de nuevo vuelo', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos});
      expect(find.text('Nuevo vuelo'), findsNothing);
    });

    testWidgets('administrador: ve el botón y abre el formulario', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos}, usuario: usuarioAdmin);
      expect(find.text('Hola, Administrador'), findsOneWidget);

      await tester.tap(find.text('Nuevo vuelo'));
      await tester.pumpAndSettle();
      expect(find.byType(CrearVueloPage), findsOneWidget);
    });
  });

  group('detalle', () {
    testWidgets('tocar un vuelo abre su detalle y el botón atrás vuelve', (tester) async {
      final api = await _abrir(tester, {
        'GET /vuelos': respuestaVuelos,
        'GET /vuelos/3': vueloQuitoGuayaquil,
      });

      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();

      expect(api.rutasSolicitadas, contains('GET /vuelos/3'));
      expect(find.byType(VueloDetallePage), findsOneWidget);
      expect(find.text('42 libres de 80'), findsOneWidget);
      expect(find.text('Precio por persona'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver a los vuelos'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('vuelo inexistente: muestra el mensaje del servidor', (tester) async {
      await _abrir(tester, {
        'GET /vuelos': respuestaVuelos,
        'GET /vuelos/3': const ServerFailure('El vuelo solicitado no existe.', statusCode: 404),
      });

      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();

      expect(find.text('El vuelo solicitado no existe.'), findsOneWidget);
    });

    testWidgets('vuelo agotado: lo indica', (tester) async {
      await _abrir(tester, {
        'GET /vuelos': respuestaVuelos,
        'GET /vuelos/3': {...vueloQuitoGuayaquil, 'asientos_disponibles': 0},
      });

      await tester.tap(find.text('KT101'));
      await tester.pumpAndSettle();

      expect(find.text('Este vuelo ya no tiene asientos disponibles.'), findsOneWidget);
    });
  });
}
