import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/controllers/sesion_controller.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<(RouteFakeRestClient, InMemoryTokenStorage)> _abrir(
  WidgetTester tester, {
  required Duration venceEn,
  Map<String, Object?> rutas = const {},
}) async {
  final tokens = InMemoryTokenStorage(jwtQueVenceEn(venceEn));
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuarioAna},
    'GET /vuelos': sinVuelos,
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: tokens);
  return (client, tokens);
}

void main() {
  group('el token vence con la app abierta', () {
    testWidgets('antes de vencer sigue dentro', (tester) async {
      await _abrir(tester, venceEn: const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 9));
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('al vencer la saca sola al login y explica por qué', (tester) async {
      final (client, tokens) = await _abrir(tester, venceEn: const Duration(minutes: 10));

      await tester.pump(const Duration(minutes: 10, seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text(mensajeSesionVencida), findsOneWidget);
      expect(await tokens.leer(), isNull); // el token vencido se descarta
      expect(client.llamadas.where((l) => l.ruta == '/auth/logout'), isEmpty); // no avisa al servidor: ya no sirve
    });

    testWidgets('si ya estaba vencido al abrir la app, también va al login con el aviso', (tester) async {
      await _abrir(tester, venceEn: const Duration(minutes: -5));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text(mensajeSesionVencida), findsOneWidget);
    });

    testWidgets('al volver a iniciar sesión el aviso desaparece', (tester) async {
      await _abrir(tester, venceEn: const Duration(minutes: 1), rutas: {'POST /auth/login': respuestaLogin, 'POST /auth/logout': {'mensaje': 'ok'}});
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(mensajeSesionVencida), findsOneWidget);

      await escribir(tester, 'Correo electrónico', 'ana@correo.com');
      await escribir(tester, 'Contraseña', 'Clave2026');
      await tocarBoton(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(VuelosPage), findsOneWidget);
      await cerrarSesionDesdeElMenu(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text(mensajeSesionVencida), findsNothing); // cerrar sesión a propósito no muestra el aviso
    });
  });

  group('el servidor rechaza el token (401)', () {
    testWidgets('una petición con 401 lleva al login con el mismo aviso', (tester) async {
      await _abrir(tester, venceEn: const Duration(hours: 1), rutas: {'GET /vuelos': const UnauthorizedFailure()});
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text(mensajeSesionVencida), findsOneWidget);
    });
  });

  group('sin vencimiento legible', () {
    testWidgets('un token que no es un JWT no programa nada y la sesión sigue', (tester) async {
      final client = RouteFakeRestClient({'GET /auth/perfil': {'usuario': usuarioAna}, 'GET /vuelos': sinVuelos});
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('token-raro'));
      await tester.pump(const Duration(hours: 5));
      expect(find.byType(VuelosPage), findsOneWidget);
    });
  });

  testWidgets('cerrar sesión cancela el temporizador (no queda nada pendiente)', (tester) async {
    await _abrir(tester, venceEn: const Duration(minutes: 30), rutas: {'POST /auth/logout': {'mensaje': 'ok'}});
    await cerrarSesionDesdeElMenu(tester);
    await tester.pump(const Duration(hours: 1));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(mensajeSesionVencida), findsNothing);
  });
}
