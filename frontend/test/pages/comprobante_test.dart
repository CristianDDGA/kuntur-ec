import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/comprobante_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<RouteFakeRestClient> _abrir(WidgetTester tester, Map<String, Object?> rutas, {Object usuario = usuarioAna}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': respuestaVuelos,
    'GET /iva': respuestaIva,
    'GET /reservas/58': reservaJson(),
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  return client;
}

Future<void> _ir(WidgetTester tester, String ruta) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(ruta);
  await tester.pumpAndSettle();
}

void main() {
  group('desde la reserva', () {
    testWidgets('el botón "Ver comprobante" abre la factura', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml()});
      await _ir(tester, AppRoutes.reserva(58));

      await tester.tap(find.text('Ver comprobante (factura XML)'));
      await tester.pumpAndSettle();

      expect(find.byType(ComprobantePage), findsOneWidget);
    });

    testWidgets('también se ofrece en una reserva cancelada (queda como anulada)', (tester) async {
      await _abrir(tester, {
        'GET /reservas/58': reservaJson(estado: 'cancelada'),
        'GET /reservas/58/comprobante': facturaXml(estado: 'Cancelada'),
      });
      await _ir(tester, AppRoutes.reserva(58));
      await tester.tap(find.text('Ver comprobante (factura XML)'));
      await tester.pumpAndSettle();

      expect(find.text('Anulada'), findsOneWidget);
    });
  });

  group('la factura', () {
    testWidgets('muestra número, fecha, cliente, asientos, montos e IVA', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml()});
      await _ir(tester, AppRoutes.comprobante(58));

      expect(find.text('Factura KEC-00000058'), findsOneWidget);
      expect(find.textContaining('Emitida el'), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('ana@correo.com'), findsOneWidget);
      expect(find.textContaining('Pasaje KT101'), findsOneWidget);
      expect(find.text('Asiento 1A'), findsOneWidget);
      expect(find.text('Asiento 1B'), findsOneWidget);
      expect(find.text(r'2 × $89.00'), findsOneWidget);
      expect(find.text(r'$178.00'), findsWidgets);
      expect(find.text('IVA (15 %)'), findsOneWidget);
      expect(find.text(r'$26.70'), findsOneWidget);
      expect(find.text(r'$204.70'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('pide el comprobante a la ruta correcta', (tester) async {
      final api = await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml()});
      await _ir(tester, AppRoutes.comprobante(58));
      expect(api.rutasSolicitadas, contains('GET /reservas/58/comprobante'));
    });

    testWidgets('un nombre con caracteres raros se ve como texto, sin interpretarse', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml(nombre: 'Ana &lt;b&gt;Negrita&lt;/b&gt; &amp; Co')});
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.text('Ana <b>Negrita</b> & Co'), findsOneWidget);
    });
  });

  group('el panel Factura XML', () {
    testWidgets('muestra el XML tal como lo entrega el servidor', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml()});
      await _ir(tester, AppRoutes.comprobante(58));

      await tester.tap(find.text('Factura XML'));
      await tester.pumpAndSettle();

      expect(find.textContaining('<factura>', findRichText: true), findsOneWidget);
      expect(find.textContaining('<numero>KEC-00000058</numero>', findRichText: true), findsOneWidget);
      expect(find.text('Copiar XML'), findsOneWidget);
      expect(find.text('Factura KEC-00000058'), findsNothing); // la vista legible ya no está
    });

    testWidgets('Copiar XML lo deja en el portapapeles y avisa', (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
        if (llamada.method == 'Clipboard.setData') copiado = (llamada.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final xml = facturaXml();
      await _abrir(tester, {'GET /reservas/58/comprobante': xml});
      await _ir(tester, AppRoutes.comprobante(58));
      await tester.tap(find.text('Factura XML'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar XML'));
      await tester.pump();

      expect(copiado, xml);
      expect(find.text('XML copiado al portapapeles.'), findsOneWidget);
    });

    testWidgets('se puede volver a la vista de la factura', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': facturaXml()});
      await _ir(tester, AppRoutes.comprobante(58));
      await tester.tap(find.text('Factura XML'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Factura').first);
      await tester.pumpAndSettle();
      expect(find.text('Factura KEC-00000058'), findsOneWidget);
    });
  });

  group('cuando algo falla', () {
    testWidgets('reserva ajena o inexistente (404): muestra el mensaje y permite reintentar', (tester) async {
      var intento = 0;
      await _abrir(tester, {
        'GET /reservas/58/comprobante': (_) => ++intento == 1 ? throw const ServerFailure('La reserva solicitada no existe.', statusCode: 404) : facturaXml(),
      });
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.text('La reserva solicitada no existe.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Factura KEC-00000058'), findsOneWidget);
    });

    testWidgets('sin conexión: avisa y permite reintentar', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': const NetworkFailure()});
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('si el servidor manda algo que no es una factura, lo dice sin romperse', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': '<html>error de un proxy</html>'});
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.text('El servidor envió una respuesta no válida.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un 401 cierra la sesión y lleva al login', (tester) async {
      await _abrir(tester, {'GET /reservas/58/comprobante': const UnauthorizedFailure()});
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('el administrador no tiene comprobantes: vuelve a la lista', (tester) async {
      final api = await _abrir(tester, {}, usuario: usuarioAdmin);
      await _ir(tester, AppRoutes.comprobante(58));
      expect(find.byType(VuelosPage), findsOneWidget);
      expect(api.rutasSolicitadas.where((r) => r.contains('comprobante')), isEmpty);
    });

    testWidgets('ids absurdos en la URL no llegan al servidor', (tester) async {
      final api = await _abrir(tester, {});
      for (final id in ['0', 'abc', '99999999999999999999', '-1']) {
        await _ir(tester, '/reservas/$id/comprobante');
        expect(find.byType(ComprobantePage), findsNothing, reason: id);
      }
      expect(api.rutasSolicitadas.where((r) => r.contains('comprobante')), isEmpty);
    });
  });
}
