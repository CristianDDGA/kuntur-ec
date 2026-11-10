import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/estado_api_page.dart';
import 'package:vuelos_app/pages/inicio_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/splash_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import 'helpers/app_helper.dart';
import 'helpers/fakes.dart';

/// Pruebas del flujo de sesión de punta a punta: arranque, rutas protegidas y cierre de sesión.
void main() {
  RouteFakeRestClient api(Map<String, Object?> rutas) => RouteFakeRestClient(rutas);

  void irA(WidgetTester tester, String ruta) {
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(appRouterProvider).go(ruta);
  }

  group('al arrancar', () {
    testWidgets('sin token no llama a la API y muestra el login', (tester) async {
      final client = api({});
      await abrirApp(tester, client: client);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(client.llamadas, isEmpty);
    });

    testWidgets('con un token válido recupera la sesión y entra al inicio', (tester) async {
      final client = api({'GET /auth/perfil': {'usuario': usuarioAna}});
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt-guardado'));

      expect(client.rutasSolicitadas, ['GET /auth/perfil']);
      expect(find.byType(InicioPage), findsOneWidget);
      expect(find.text('Hola, Ana Torres'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
    });

    testWidgets('con un token vencido o revocado lo descarta y pide iniciar sesión', (tester) async {
      final tokens = InMemoryTokenStorage('jwt-vencido');
      final client = api({'GET /auth/perfil': const UnauthorizedFailure('La sesión fue cerrada.')});
      await abrirApp(tester, client: client, tokens: tokens);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(await tokens.leer(), isNull);
    });

    testWidgets('mientras valida el token se ve la pantalla de carga', (tester) async {
      final client = api({'GET /auth/perfil': (_) => Future<Object?>.delayed(const Duration(seconds: 1), () => {'usuario': usuarioAna})});
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'), esperar: false);
      await tester.pump();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('Verificando su sesión…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);
    });

    testWidgets('con el servidor caído conserva el token y permite reintentar', (tester) async {
      final tokens = InMemoryTokenStorage('jwt-guardado');
      var caido = true;
      final client = api({
        'GET /auth/perfil': (_) => caido ? throw const NetworkFailure() : {'usuario': usuarioAna},
      });
      await abrirApp(tester, client: client, tokens: tokens);

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
      expect(await tokens.leer(), 'jwt-guardado'); // un corte de red no cierra la sesión

      caido = false;
      await tocarBoton(tester, 'Reintentar');
      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);
    });

    testWidgets('con el servidor caído se puede seguir hacia el login', (tester) async {
      final client = api({'GET /auth/perfil': const NetworkFailure()});
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      await tocarBoton(tester, 'Ir a iniciar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('rutas protegidas', () {
    testWidgets('sin sesión no se puede entrar al inicio', (tester) async {
      await abrirApp(tester, client: api({}));

      irA(tester, AppRoutes.inicio);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(InicioPage), findsNothing);
    });

    testWidgets('sin sesión el estado del servicio sí es público', (tester) async {
      await abrirApp(tester, client: api({'GET /health': healthOk}));

      irA(tester, AppRoutes.estado);
      await tester.pumpAndSettle();

      expect(find.byType(EstadoApiPage), findsOneWidget);
    });

    testWidgets('con sesión, login y registro redirigen al inicio', (tester) async {
      await abrirApp(tester,
          client: api({'GET /auth/perfil': {'usuario': usuarioAna}}), tokens: InMemoryTokenStorage('jwt'));

      irA(tester, AppRoutes.login);
      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);

      irA(tester, AppRoutes.registro);
      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);
    });
  });

  group('cerrar sesión', () {
    testWidgets('avisa al servidor, borra el token y vuelve al login', (tester) async {
      final tokens = InMemoryTokenStorage('jwt');
      final client = api({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'POST /auth/logout': {'mensaje': 'Sesión cerrada correctamente.'},
      });
      await abrirApp(tester, client: client, tokens: tokens);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(client.rutasSolicitadas, ['GET /auth/perfil', 'POST /auth/logout']);
      expect(await tokens.leer(), isNull);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('aunque el servidor no responda, la sesión local se cierra', (tester) async {
      final tokens = InMemoryTokenStorage('jwt');
      final client = api({
        'GET /auth/perfil': {'usuario': usuarioAna},
        'POST /auth/logout': const NetworkFailure(),
      });
      await abrirApp(tester, client: client, tokens: tokens);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(await tokens.leer(), isNull);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('después de cerrar sesión no se recuerda el error del intento anterior', (tester) async {
      final client = api({
        'POST /auth/login': const UnauthorizedFailure('Correo o contraseña incorrectos.'),
      });
      await abrirApp(tester, client: client);
      await escribir(tester, 'Correo electrónico', 'ana@correo.com');
      await escribir(tester, 'Contraseña', 'Mala12345');
      await tocarBoton(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      // Se va al registro y se vuelve: la pantalla del login empieza limpia.
      await tocarBoton(tester, 'Cree una');
      await tester.pumpAndSettle();
      await tocarBoton(tester, 'Inicie sesión');
      await tester.pumpAndSettle();

      expect(find.text('Correo o contraseña incorrectos.'), findsNothing);
    });
  });
}
