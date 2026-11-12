import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/reservas_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';

import 'helpers/app_helper.dart';
import 'helpers/fakes.dart';

void main() {
  group('destinoSeguro', () {
    test('acepta rutas internas de la app', () {
      for (final ok in ['/reservas', '/reservas/58', '/reservas/58/comprobante', '/vuelos/3?x=1', '/admin']) {
        expect(destinoSeguro(ok), ok);
      }
    });

    test('rechaza todo lo que pueda sacar al usuario de la app o llevarlo a una pantalla de entrada', () {
      for (final malo in <String?>[
        null,
        '',
        'reservas',
        '//sitio-malo.com',
        'https://sitio-malo.com',
        'http://sitio-malo.com/reservas',
        'javascript:alert(1)',
        r'/\sitio-malo.com',
        '/login',
        '/registro',
        '/cargando',
        '/login?volver=/reservas',
        '/${'a' * 300}',
      ]) {
        expect(destinoSeguro(malo), isNull, reason: '$malo');
      }
    });
  });

  group('volver a donde estaba', () {
    Future<RouteFakeRestClient> abrir(WidgetTester tester) async {
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': sinVuelos,
        'GET /reservas': sinReservas,
        'POST /auth/login': respuestaLogin,
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
      return client;
    }

    void irA(WidgetTester tester, String ruta) =>
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).go(ruta);

    testWidgets('la carga con "volver" lleva a esa pantalla (recargar la página no pierde dónde estaba)', (tester) async {
      await abrir(tester);
      irA(tester, '/cargando?volver=${Uri.encodeQueryComponent('/reservas')}');
      await tester.pumpAndSettle();
      expect(find.byType(ReservasPage), findsOneWidget);
    });

    testWidgets('un "volver" malicioso se ignora y va al inicio', (tester) async {
      await abrir(tester);
      for (final malo in ['https://sitio-malo.com', '//sitio-malo.com', '/login']) {
        irA(tester, '/cargando?volver=${Uri.encodeQueryComponent(malo)}');
        await tester.pumpAndSettle();
        expect(find.byType(VuelosPage), findsOneWidget, reason: malo);
      }
    });

    testWidgets('si la sesión venció estando en /reservas, al volver a entrar regresa a /reservas', (tester) async {
      final tokens = InMemoryTokenStorage(jwtQueVenceEn(const Duration(minutes: 5)));
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': sinVuelos,
        'GET /reservas': sinReservas,
        'POST /auth/login': respuestaLogin,
      });
      await abrirApp(tester, client: client, tokens: tokens);
      irA(tester, '/reservas');
      await tester.pumpAndSettle();
      expect(find.byType(ReservasPage), findsOneWidget);

      await tester.pump(const Duration(minutes: 5, seconds: 1)); // vence el token
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await escribir(tester, 'Correo electrónico', 'ana@correo.com');
      await escribir(tester, 'Contraseña', 'Clave2026');
      await tocarBoton(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(ReservasPage), findsOneWidget); // volvió a donde estaba
    });

    testWidgets('al cerrar sesión a propósito NO se recuerda la pantalla (el siguiente usuario empieza limpio)', (tester) async {
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'GET /vuelos': sinVuelos,
        'GET /reservas': sinReservas,
        'POST /auth/login': respuestaLogin,
        'POST /auth/logout': {'mensaje': 'ok'},
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
      irA(tester, '/reservas');
      await tester.pumpAndSettle();

      await cerrarSesionDesdeElMenu(tester);
      await escribir(tester, 'Correo electrónico', 'ana@correo.com');
      await escribir(tester, 'Contraseña', 'Clave2026');
      await tocarBoton(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(VuelosPage), findsOneWidget); // al inicio, no en /reservas
    });
  });
}
