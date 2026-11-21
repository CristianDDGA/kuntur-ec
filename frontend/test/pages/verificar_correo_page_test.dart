import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/verificar_correo_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

const _registroOk = {
  'mensaje': 'ok',
  'usuario': usuarioAna,
  'verificacion_pendiente': true,
  'codigo_enviado': true,
};
const _sinVerificar = ServerFailure(
  'Falta verificar su correo. Ingrese el código que le enviamos.',
  statusCode: 403,
  codigo: 'correo_no_verificado',
  detalles: {'correo': 'ana@correo.com'},
);

RouteFakeRestClient _api({Map<String, Object?> extra = const {}}) => RouteFakeRestClient({
      'POST /usuarios/registro': _registroOk,
      'POST /auth/verificar-correo': {'mensaje': 'ok', 'correo': 'ana@correo.com'},
      'POST /auth/reenviar-codigo': {'mensaje': 'Si la cuenta existe y falta verificarla, le enviamos un código nuevo.'},
      'POST /auth/login': respuestaLogin,
      'GET /vuelos': sinVuelos,
      ...extra,
    });

Future<void> _registrarse(WidgetTester tester, RouteFakeRestClient client) async {
  await abrirApp(tester, client: client);
  await tocarBoton(tester, 'Cree una');
  await tester.pumpAndSettle();
  await escribir(tester, 'Nombre completo', 'Ana Torres');
  await escribir(tester, 'Cédula de identidad', '1710034065');
  await escribir(tester, 'Correo electrónico', 'ana@correo.com');
  await escribir(tester, 'Contraseña', 'Clave2026');
  await escribir(tester, 'Repita la contraseña', 'Clave2026');
  await tocarBoton(tester, 'Crear cuenta');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el código correcto verifica el correo, inicia sesión solo y entra', (tester) async {
    final tokens = InMemoryTokenStorage();
    final client = _api();
    usarPantallaGrande(tester);
    await _registrarse(tester, client);
    expect(find.byType(VerificarCorreoPage), findsOneWidget);

    await escribir(tester, 'Código de verificación', '123456');
    await tocarBoton(tester, 'Verificar');
    await tester.pumpAndSettle();

    expect(client.llamada('POST', '/auth/verificar-correo').cuerpo, {'correo': 'ana@correo.com', 'codigo': '123456'});
    expect(client.llamada('POST', '/auth/login').cuerpo, {'correo': 'ana@correo.com', 'password': 'Clave2026'});
    expect(find.byType(VuelosPage), findsOneWidget);
    expect(await tokens.leer(), isNull); // (este helper usa su propio almacén; lo importante es que entró)
  });

  testWidgets('un código vacío o incompleto no llama a la API', (tester) async {
    final client = _api();
    await _registrarse(tester, client);

    await tocarBoton(tester, 'Verificar');
    expect(find.text('Ingrese el código que le enviamos.'), findsOneWidget);
    await escribir(tester, 'Código de verificación', '123');
    await tocarBoton(tester, 'Verificar');
    expect(find.text('El código tiene 6 dígitos.'), findsOneWidget);
    expect(client.rutasSolicitadas, ['POST /usuarios/registro']);
  });

  testWidgets('el campo solo admite dígitos y hasta 6', (tester) async {
    await _registrarse(tester, _api());

    await escribir(tester, 'Código de verificación', '12ab-34 56789');

    expect(tester.widget<TextFormField>(campo('Código de verificación')).controller!.text, '123456');
  });

  testWidgets('un código incorrecto muestra el mensaje del servidor y se queda en la pantalla', (tester) async {
    final client = _api(extra: {
      'POST /auth/verificar-correo':
          const ServerFailure('El código no es correcto. Le quedan 4 intentos.', statusCode: 400, codigo: 'datos_invalidos'),
    });
    await _registrarse(tester, client);

    await escribir(tester, 'Código de verificación', '000000');
    await tocarBoton(tester, 'Verificar');
    await tester.pumpAndSettle();

    expect(find.text('El código no es correcto. Le quedan 4 intentos.'), findsOneWidget);
    expect(find.byType(VerificarCorreoPage), findsOneWidget);
    expect(client.rutasSolicitadas.where((r) => r == 'POST /auth/login'), isEmpty); // no inicia sesión
  });

  testWidgets('reenviar: está bloqueado 60 s y luego pide un código nuevo', (tester) async {
    final client = _api();
    await _registrarse(tester, client);

    expect(find.textContaining('Reenviar código en'), findsOneWidget); // el código acaba de enviarse
    await tester.tap(find.textContaining('Reenviar código en'));
    await tester.pump();
    expect(client.rutasSolicitadas.where((r) => r == 'POST /auth/reenviar-codigo'), isEmpty);

    await tester.pump(const Duration(seconds: esperaReenvioSegundos + 1));
    expect(find.text('Reenviar código'), findsOneWidget);
    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(client.llamada('POST', '/auth/reenviar-codigo').cuerpo, {'correo': 'ana@correo.com'});
    expect(find.textContaining('le enviamos un código nuevo'), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsOneWidget); // vuelve a esperar
  });

  testWidgets('si el correo del registro no salió, pide un código nuevo al abrir la pantalla', (tester) async {
    final client = _api(extra: {'POST /usuarios/registro': {..._registroOk, 'codigo_enviado': false}});
    await _registrarse(tester, client);

    expect(client.rutasSolicitadas, ['POST /usuarios/registro', 'POST /auth/reenviar-codigo']);
  });

  testWidgets('iniciar sesión con el correo sin verificar lleva a pedir el código (sin mostrar error)', (tester) async {
    final client = _api(extra: {'POST /auth/login': _sinVerificar});
    await abrirApp(tester, client: client);
    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.byType(VerificarCorreoPage), findsOneWidget);
    expect(find.textContaining('Falta verificar su correo'), findsNothing); // no es un error: es un paso
    // El código anterior pudo vencer: se pide uno nuevo al llegar.
    expect(client.rutasSolicitadas, ['POST /auth/login', 'POST /auth/reenviar-codigo']);
  });

  testWidgets('otro error de login (clave mala) sigue siendo un error normal', (tester) async {
    final client = _api(extra: {'POST /auth/login': const UnauthorizedFailure('Correo o contraseña incorrectos.')});
    await abrirApp(tester, client: client);
    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Mala2026');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('sin una cuenta pendiente (p. ej. al recargar) la pantalla no existe: va al login', (tester) async {
    await abrirApp(tester, client: _api());
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(appRouterProvider)
        .go(AppRoutes.verificarCorreo);
    await tester.pumpAndSettle();

    expect(find.byType(VerificarCorreoPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('"Volver a iniciar sesión" olvida la cuenta pendiente', (tester) async {
    await _registrarse(tester, _api());

    await tocarBoton(tester, 'Volver a iniciar sesión');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(appRouterProvider)
        .go(AppRoutes.verificarCorreo);
    await tester.pumpAndSettle();
    expect(find.byType(VerificarCorreoPage), findsNothing); // ya no hay nada pendiente
  });

  testWidgets('verificado pero el login automático falla: lleva al login con el motivo', (tester) async {
    final client = _api(extra: {'POST /auth/login': const NetworkFailure()});
    await _registrarse(tester, client);

    await escribir(tester, 'Código de verificación', '123456');
    await tocarBoton(tester, 'Verificar');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.textContaining('Su correo quedó verificado'), findsOneWidget);
  });
}
