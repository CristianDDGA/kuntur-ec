import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/completar_cedula_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/registro_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';
import '../helpers/google_falso.dart';

/// Cuenta que Google acaba de crear: correo verificado, sin cédula.
const _usuarioGoogle = {
  'id': 21,
  'nombre': 'Gabi Google',
  'correo': 'gabi@gmail.com',
  'rol': 'cliente',
  'fecha_registro': '2026-11-20T10:00:00+00:00',
  'cedula': null,
  'correo_verificado': true,
};

Map<String, Object?> _sesion(Map<String, Object?> usuario, {bool nuevo = false}) => {
      'token': 'jwt-google',
      'tipo': 'Bearer',
      'expira': '2026-11-10T16:04:04+00:00',
      'usuario': usuario,
      'nuevo': nuevo,
    };

RouteFakeRestClient _api({Map<String, Object?> extra = const {}}) => RouteFakeRestClient({
      'POST /auth/google': _sesion(_usuarioGoogle, nuevo: true),
      'PUT /usuarios/cedula': {'mensaje': 'ok', 'usuario': {..._usuarioGoogle, 'cedula': '1710034065'}},
      'GET /vuelos': sinVuelos,
      ...extra,
    });

void _irA(WidgetTester tester, String ruta) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).go(ruta);

void main() {
  group('el botón de Google', () {
    testWidgets('si Google no está disponible no aparece (ni en login ni en registro)', (tester) async {
      await abrirApp(tester, client: _api()); // por defecto: no disponible
      expect(find.text('Continuar con Google'), findsNothing);
      expect(find.text('o continúe con'), findsNothing);

      await tocarBoton(tester, 'Cree una');
      await tester.pumpAndSettle();
      expect(find.byType(RegistroPage), findsOneWidget);
      expect(find.text('Continuar con Google'), findsNothing);
    });

    testWidgets('si está disponible aparece en login y en registro, y prepara el SDK una vez por pantalla', (tester) async {
      final google = ProveedorGoogleFalso();
      await abrirApp(tester, client: _api(), google: google);
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(google.vecesIniciado, 1);

      await tocarBoton(tester, 'Cree una');
      await tester.pumpAndSettle();
      expect(find.text('Continuar con Google'), findsOneWidget);
    });
  });

  group('iniciar sesión con Google', () {
    testWidgets('envía el id_token al servidor (y nada más) y entra', (tester) async {
      final client = _api(extra: {'POST /auth/google': _sesion(usuarioAna)});
      await abrirApp(tester, client: client, google: ProveedorGoogleFalso(alTocar: 'token-firmado-por-google'));

      await tocarBoton(tester, 'Continuar con Google');
      await tester.pumpAndSettle();

      expect(client.llamada('POST', '/auth/google').cuerpo, {'id_token': 'token-firmado-por-google'}); // solo el token
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('también sirve para crear la cuenta desde la pantalla de registro', (tester) async {
      final client = _api(extra: {'POST /auth/google': _sesion(usuarioAna, nuevo: true)});
      await abrirApp(tester, client: client, google: ProveedorGoogleFalso());
      await tocarBoton(tester, 'Cree una');
      await tester.pumpAndSettle();

      await tocarBoton(tester, 'Continuar con Google');
      await tester.pumpAndSettle();

      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('un token rechazado muestra el mensaje y se queda en el login, sin sesión', (tester) async {
      final client = _api(extra: {
        'POST /auth/google': const UnauthorizedFailure('No se pudo validar su cuenta de Google. Intente de nuevo.'),
      });
      await abrirApp(tester, client: client, google: ProveedorGoogleFalso());

      await tocarBoton(tester, 'Continuar con Google');
      await tester.pumpAndSettle();

      expect(find.text('No se pudo validar su cuenta de Google. Intente de nuevo.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('si Google no está configurado en el servidor (503) lo explica', (tester) async {
      final client = _api(extra: {
        'POST /auth/google': const ServerFailure('El inicio de sesión con Google no está disponible en este momento.', statusCode: 503),
      });
      await abrirApp(tester, client: client, google: ProveedorGoogleFalso());

      await tocarBoton(tester, 'Continuar con Google');
      await tester.pumpAndSettle();

      expect(find.textContaining('no está disponible en este momento'), findsOneWidget);
    });

    testWidgets('dos tokens seguidos envían una sola petición', (tester) async {
      final google = ProveedorGoogleFalso();
      final client = _api(extra: {
        'POST /auth/google': (_) => Future<Object?>.delayed(const Duration(seconds: 1), () => _sesion(usuarioAna)),
      });
      await abrirApp(tester, client: client, google: google);

      google.simularInicio('uno');
      google.simularInicio('dos');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(client.llamadas.where((l) => l.ruta == '/auth/google'), hasLength(1));
    });
  });

  group('completar la cédula', () {
    Future<RouteFakeRestClient> entrarConGoogleSinCedula(WidgetTester tester, {Map<String, Object?> extra = const {}}) async {
      final client = _api(extra: extra);
      await abrirApp(tester, client: client, google: ProveedorGoogleFalso());
      await tocarBoton(tester, 'Continuar con Google');
      await tester.pumpAndSettle();
      return client;
    }

    testWidgets('una cuenta nueva de Google sin cédula debe completarla antes de usar la app', (tester) async {
      await entrarConGoogleSinCedula(tester);

      expect(find.byType(CompletarCedulaPage), findsOneWidget);
      expect(find.byType(VuelosPage), findsNothing);
      expect(find.textContaining('Gabi'), findsWidgets); // saluda por su nombre
    });

    testWidgets('no se puede saltar la pantalla yendo a otra ruta', (tester) async {
      await entrarConGoogleSinCedula(tester);

      _irA(tester, AppRoutes.vuelos);
      await tester.pumpAndSettle();
      expect(find.byType(CompletarCedulaPage), findsOneWidget);

      _irA(tester, AppRoutes.reservas);
      await tester.pumpAndSettle();
      expect(find.byType(CompletarCedulaPage), findsOneWidget);
    });

    testWidgets('una cédula inválida se rechaza antes de enviar', (tester) async {
      final client = await entrarConGoogleSinCedula(tester);

      await escribir(tester, 'Cédula de identidad', '1710034066');
      await tocarBoton(tester, 'Guardar y continuar');

      expect(find.textContaining('Esta cédula no es válida'), findsOneWidget);
      expect(client.llamadas.where((l) => l.metodo == 'PUT'), isEmpty);
    });

    testWidgets('con una cédula válida se guarda y se entra a la app', (tester) async {
      final client = await entrarConGoogleSinCedula(tester);

      await escribir(tester, 'Cédula de identidad', '1710034065');
      await tocarBoton(tester, 'Guardar y continuar');
      await tester.pumpAndSettle();

      expect(client.llamada('PUT', '/usuarios/cedula').cuerpo, {'cedula': '1710034065'});
      expect(find.byType(VuelosPage), findsOneWidget);
      expect(find.byType(CompletarCedulaPage), findsNothing);
    });

    testWidgets('una cédula ya registrada (409) muestra el mensaje y sigue pidiéndola', (tester) async {
      await entrarConGoogleSinCedula(tester, extra: {
        'PUT /usuarios/cedula': const ServerFailure('Ya existe una cuenta registrada con esa cédula.', statusCode: 409),
      });

      await escribir(tester, 'Cédula de identidad', '1710034065');
      await tocarBoton(tester, 'Guardar y continuar');
      await tester.pumpAndSettle();

      expect(find.text('Ya existe una cuenta registrada con esa cédula.'), findsOneWidget);
      expect(find.byType(CompletarCedulaPage), findsOneWidget);
    });

    testWidgets('también se pide a un cliente antiguo que entra con contraseña y no tiene cédula', (tester) async {
      final sinCedula = {...usuarioAna}..remove('cedula');
      final client = _api(extra: {'POST /auth/login': {...respuestaLogin, 'usuario': sinCedula}});
      await abrirApp(tester, client: client);
      await escribir(tester, 'Correo electrónico', 'ana@correo.com');
      await escribir(tester, 'Contraseña', 'Clave2026');
      await tocarBoton(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(CompletarCedulaPage), findsOneWidget);
    });

    testWidgets('el administrador no necesita cédula', (tester) async {
      final client = RouteFakeRestClient({
        'GET /auth/perfil': {'usuario': usuarioAdmin}, // sin cédula
        'GET /vuelos': sinVuelos,
      });
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      expect(find.byType(VuelosPage), findsOneWidget);
      expect(find.byType(CompletarCedulaPage), findsNothing);
    });

    testWidgets('quien ya tiene cédula no ve la pantalla aunque entre a su ruta', (tester) async {
      final client = RouteFakeRestClient({'GET /auth/perfil': {'usuario': usuarioAna}, 'GET /vuelos': sinVuelos});
      await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));

      _irA(tester, AppRoutes.completarCedula);
      await tester.pumpAndSettle();

      expect(find.byType(CompletarCedulaPage), findsNothing);
      expect(find.byType(VuelosPage), findsOneWidget);
    });

    testWidgets('"Cerrar sesión" desde esta pantalla vuelve al login', (tester) async {
      await entrarConGoogleSinCedula(tester, extra: {'POST /auth/logout': {'mensaje': 'ok'}});

      await tocarBoton(tester, 'Cerrar sesión');
      await tester.pumpAndSettle();

      expect(find.byType(CompletarCedulaPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
