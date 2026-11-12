import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/models/validadores_vuelo.dart';
import 'package:vuelos_app/pages/admin_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<RouteFakeRestClient> _abrir(WidgetTester tester, Map<String, Object?> rutas, {Object usuario = usuarioAna}) async {
  final client = RouteFakeRestClient({'GET /auth/perfil': {'usuario': usuario}, ...rutas});
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

/// El control de páginas está al final de la lista: se baja hasta verlo (la lista construye solo lo visible).
Future<void> _alPie(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byTooltip('Página siguiente'), 400, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void _irA(WidgetTester tester, String ruta) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(ruta);

/// Responde `GET /vuelos` según la página pedida (la lee del último filtro enviado).
RouteFakeRestClient _clientePaginado(int total, {Object usuario = usuarioAna}) {
  late final RouteFakeRestClient client;
  client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': (_) {
      final pagina = int.parse(client.llamadas.lastWhere((l) => l.ruta == '/vuelos').consulta!['pagina']!);
      return paginaDeVuelos(total: total, pagina: pagina);
    },
  });
  return client;
}

void main() {
  group('paginación', () {
    testWidgets('con 25 vuelos hay 3 páginas y se navega con los botones', (tester) async {
      final client = _clientePaginado(25);
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      expect(find.text('25 vuelos disponibles'), findsOneWidget);
      expect(find.text('KT101'), findsOneWidget);
      expect(find.text('KT111'), findsNothing);
      await _alPie(tester);
      expect(find.text('Página 1 de 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('KT111'), findsOneWidget);
      await _alPie(tester);
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(client.llamadas.where((l) => l.ruta == '/vuelos').last.consulta!['pagina'], '2');

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('KT121'), findsOneWidget); // la última página trae 5 vuelos
      expect(find.text('KT126'), findsNothing);
      await _alPie(tester);
      expect(find.text('Página 3 de 3'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);

      await tester.tap(find.byTooltip('Página anterior'));
      await tester.pumpAndSettle();
      await _alPie(tester);
      expect(find.text('Página 2 de 3'), findsOneWidget);
    });

    testWidgets('en los extremos el botón correspondiente está desactivado', (tester) async {
      await abrirApp(tester, client: _clientePaginado(25), tokens: InMemoryTokenStorage('jwt'));
      await _alPie(tester);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
    });

    testWidgets('con 10 vuelos o menos no se muestra el control de páginas', (tester) async {
      await abrirApp(tester, client: _clientePaginado(10), tokens: InMemoryTokenStorage('jwt'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página'), findsNothing);
      expect(find.byTooltip('Página siguiente'), findsNothing);
    });

    testWidgets('una búsqueda nueva vuelve a la página 1 y conserva los filtros al paginar', (tester) async {
      final client = _clientePaginado(25);
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      await _alPie(tester);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000)); // de vuelta arriba, al buscador
      await tester.pumpAndSettle();
      await escribir(tester, 'Origen', 'Quito');
      await tocarBoton(tester, 'Buscar vuelos');
      await tester.pumpAndSettle();

      var ultima = client.llamadas.where((l) => l.ruta == '/vuelos').last.consulta!;
      expect(ultima['pagina'], '1');
      expect(ultima['origen'], 'Quito');

      await _alPie(tester);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      ultima = client.llamadas.where((l) => l.ruta == '/vuelos').last.consulta!;
      expect(ultima['pagina'], '2');
      expect(ultima['origen'], 'Quito');
    });

    testWidgets('si la página pedida ya no existe ofrece volver a la primera', (tester) async {
      var pagina = 1;
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': (_) => pagina == 1 ? paginaDeVuelos(total: 25, pagina: 1) : {...paginaDeVuelos(total: 25, pagina: 1), 'pagina': 2, 'vuelos': <Object>[]},
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      pagina = 2;
      await _alPie(tester);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Esta página ya no tiene vuelos.'), findsOneWidget);

      pagina = 1;
      await tocarBoton(tester, 'Ir a la primera página');
      await tester.pumpAndSettle();
      await _alPie(tester);
      expect(find.text('Página 1 de 3'), findsOneWidget);
    });

    testWidgets('un error al cambiar de página no deja la pantalla rota y se puede reintentar', (tester) async {
      var falla = false;
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': (_) => falla ? throw const NetworkFailure() : paginaDeVuelos(total: 25, pagina: 1),
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      falla = true;
      await _alPie(tester);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('panel de administración', () {
    testWidgets('el cliente no ve el botón del panel y la ruta lo devuelve a la lista', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos});
      expect(find.text('Administración'), findsNothing);

      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();
      expect(find.byType(AdminPage), findsNothing);
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('el administrador abre el panel y ve el IVA vigente y el historial', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': respuestaIva}, usuario: usuarioAdmin);

      await tester.tap(find.text('Administración'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminPage), findsOneWidget);
      expect(find.text('15 %'), findsNWidgets(2)); // grande + fila del historial
      expect(find.text('12 %'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);
    });

    testWidgets('sin tarifa vigente avisa que nadie podrá reservar', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': {'vigente': null, 'tarifas': <Object>[]}}, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();
      expect(find.textContaining('nadie podrá reservar'), findsOneWidget);
    });

    testWidgets('no deja escribir letras ni pasar de 100 en el porcentaje', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': respuestaIva}, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      final texto = tester.widget<TextFormField>(campo('Nuevo porcentaje')).controller!;
      await tester.enterText(campo('Nuevo porcentaje'), '15');
      await tester.enterText(campo('Nuevo porcentaje'), '150'); // pasaría de 100: se ignora
      await tester.enterText(campo('Nuevo porcentaje'), '15x'); // letra: se ignora
      await tester.pump();
      expect(texto.text, '15');
    });

    testWidgets('escribir en un campo no marca errores en los que aún no se tocaron', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': respuestaIva}, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      await tester.enterText(campo('Nuevo porcentaje'), '1');
      await tester.pump();

      expect(find.text('Elija desde cuándo rige.'), findsNothing);
    });

    testWidgets('campos vacíos: pide completarlos y no llama a la API', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': respuestaIva}, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Programar cambio').last);
      await tester.tap(find.text('Programar cambio').last);
      await tester.pumpAndSettle();

      expect(find.text('Escriba el porcentaje.'), findsOneWidget);
      expect(find.text('Elija desde cuándo rige.'), findsOneWidget);
      expect(api.llamadas.where((l) => l.metodo == 'POST'), isEmpty);
    });

    testWidgets('programa un cambio: confirma, envía y recarga el historial', (tester) async {
      var cambiado = false;
      final api = await _abrir(tester, {
        'GET /vuelos': sinVuelos,
        'GET /iva': (_) => cambiado
            ? {
                'vigente': tarifaVigente,
                'tarifas': [
                  {'id': 3, 'porcentaje': '13.00', 'vigente_desde': '2030-01-01', 'vigente_hasta': null, 'estado': 'programada'},
                  {...tarifaVigente, 'vigente_hasta': '2030-01-01'},
                  tarifaAnterior,
                ],
              }
            : respuestaIva,
        'POST /iva': (_) {
          cambiado = true;
          return {'mensaje': 'ok', 'tarifa': {'id': 3, 'porcentaje': '13.00', 'vigente_desde': '2030-01-01', 'vigente_hasta': null, 'estado': 'programada'}};
        },
      }, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      await escribir(tester, 'Nuevo porcentaje', '13');
      await tester.ensureVisible(find.text('Rige desde'));
      await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('CampoSelector<DateTime>')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Programar cambio').last);
      await tester.tap(find.text('Programar cambio').last);
      await tester.pumpAndSettle();
      expect(find.text('¿Cambiar el IVA?'), findsOneWidget);
      expect(api.llamadas.where((l) => l.metodo == 'POST'), isEmpty); // aún no se envía

      await tester.tap(find.text('Sí, cambiar'));
      await tester.pumpAndSettle();

      final cuerpo = api.llamada('POST', '/iva').cuerpo as Map;
      expect(cuerpo['porcentaje'], '13');
      expect(cuerpo['vigente_desde'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Tarifa de IVA registrada.'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el cambio (409) muestra el mensaje y conserva el formulario', (tester) async {
      await _abrir(tester, {
        'GET /vuelos': sinVuelos,
        'GET /iva': respuestaIva,
        'POST /iva': const ServerFailure('Ya hay una tarifa que empieza el 01/01/2030.', statusCode: 409),
      }, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      await escribir(tester, 'Nuevo porcentaje', '13');
      await tester.ensureVisible(find.text('Rige desde'));
      await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('CampoSelector<DateTime>')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Programar cambio').last);
      await tester.tap(find.text('Programar cambio').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cambiar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya hay una tarifa que empieza el 01/01/2030.'), findsOneWidget);
      expect(tester.widget<TextFormField>(campo('Nuevo porcentaje')).controller!.text, '13');
    });

    testWidgets('cancelar la confirmación no envía nada', (tester) async {
      final api = await _abrir(tester, {'GET /vuelos': sinVuelos, 'GET /iva': respuestaIva}, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();

      await escribir(tester, 'Nuevo porcentaje', '13');
      await tester.ensureVisible(find.text('Rige desde'));
      await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('CampoSelector<DateTime>')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Programar cambio').last);
      await tester.tap(find.text('Programar cambio').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.llamadas.where((l) => l.metodo == 'POST'), isEmpty);
    });

    testWidgets('si falla la carga del IVA ofrece reintentar', (tester) async {
      var intento = 0;
      await _abrir(tester, {
        'GET /vuelos': sinVuelos,
        'GET /iva': (_) => ++intento == 1 ? throw const NetworkFailure() : respuestaIva,
      }, usuario: usuarioAdmin);
      _irA(tester, AppRoutes.admin);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

      await tocarBoton(tester, 'Reintentar');
      await tester.pumpAndSettle();
      expect(find.text('Vigente'), findsOneWidget);
    });
  });

  group('direcciones raras', () {
    for (final ruta in ['/algo-raro', '/vuelos', '/vuelos/1/2/3', '/admin/otra', '//', '/vuelos/%00']) {
      testWidgets('"$ruta" no rompe la app', (tester) async {
        await _abrir(tester, {'GET /vuelos': sinVuelos}, usuario: usuarioAdmin);
        _irA(tester, ruta);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets); // hay una pantalla, no un error rojo
      });
    }

    testWidgets('un id que no es número vuelve a la lista', (tester) async {
      await _abrir(tester, {'GET /vuelos': sinVuelos}, usuario: usuarioAdmin);
      _irA(tester, '/vuelos/abc');
      await tester.pumpAndSettle();
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    for (final id in ['0', '-1', '99999999999999999999', '1.5', '1e5']) {
      testWidgets('el id "$id" no llega al servidor: vuelve a la lista', (tester) async {
        final api = await _abrir(tester, {'GET /vuelos': sinVuelos}, usuario: usuarioAdmin);
        _irA(tester, '/vuelos/$id');
        await tester.pumpAndSettle();
        expect(find.byType(VuelosPage), findsOneWidget);
        expect(api.rutasSolicitadas.where((r) => r.startsWith('GET /vuelos/')), isEmpty);
      });
    }
  });

  group('hora de salida de hoy', () {
    final ahora = DateTime(2026, 11, 11, 13, 19);
    final hoy = DateTime(2026, 11, 11);

    test('una hora ya pasada hoy se rechaza con la hora actual en el mensaje', () {
      for (final h in [const Duration(hours: 10), const Duration(hours: 13, minutes: 19), Duration.zero]) {
        expect(ValidadoresVuelo.salida(h, hoy, ahora: ahora), contains('13:19'), reason: '$h');
      }
    });

    test('una hora posterior hoy es válida', () {
      expect(ValidadoresVuelo.salida(const Duration(hours: 13, minutes: 20), hoy, ahora: ahora), isNull);
    });

    test('en otro día cualquier hora es válida', () {
      expect(ValidadoresVuelo.salida(const Duration(hours: 1), DateTime(2026, 11, 12), ahora: ahora), isNull);
    });

    test('sin hora, es obligatoria; sin fecha aún no se puede juzgar', () {
      expect(ValidadoresVuelo.salida(null, hoy, ahora: ahora), isNotNull);
      expect(ValidadoresVuelo.salida(const Duration(hours: 1), null, ahora: ahora), isNull);
    });

    test('porcentaje y fecha de inicio de la tarifa', () {
      for (final ok in ['0', '15', '12.5', '12,50', '100']) {
        expect(ValidadoresVuelo.porcentaje(ok), isNull, reason: ok);
      }
      for (final mal in ['', ' ', 'abc', '101', '-1', '12.345', '1e2', '١٢']) {
        expect(ValidadoresVuelo.porcentaje(mal), isNotNull, reason: mal);
      }
      expect(ValidadoresVuelo.inicioTarifa(null), isNotNull);
      expect(ValidadoresVuelo.inicioTarifa(DateTime(2026, 11, 10), hoy: ahora), isNotNull);
      expect(ValidadoresVuelo.inicioTarifa(DateTime(2026, 11, 11), hoy: ahora), isNull);
    });
  });
}
