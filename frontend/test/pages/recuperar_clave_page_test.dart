import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/recuperar_clave_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

const _mensajeSolicitud = 'Si el correo está registrado, le enviamos un código para restablecer su contraseña.';
const _mensajeListo = 'Contraseña actualizada. Inicie sesión con la nueva contraseña.';

RouteFakeRestClient _api({Map<String, Object?> extra = const {}}) => RouteFakeRestClient({
      'POST /auth/recuperar-clave': {'mensaje': _mensajeSolicitud},
      'POST /auth/restablecer-clave': {'mensaje': _mensajeListo},
      ...extra,
    });

Future<void> _abrirRecuperacion(WidgetTester tester, RouteFakeRestClient client) async {
  await abrirApp(tester, client: client);
  await tocarBoton(tester, '¿Olvidó su contraseña?');
  await tester.pumpAndSettle();
}

Future<void> _pedirCodigo(WidgetTester tester, {String correo = 'ana@correo.com'}) async {
  await escribir(tester, 'Correo electrónico', correo);
  await tocarBoton(tester, 'Enviar código');
  await tester.pumpAndSettle();
}

Future<void> _llenarSegundoPaso(WidgetTester tester, {String codigo = '123456', String password = 'Nueva2026'}) async {
  await escribir(tester, 'Código de verificación', codigo);
  await escribir(tester, 'Contraseña nueva', password);
  await escribir(tester, 'Repita la contraseña', password);
}

void main() {
  testWidgets('el login tiene el enlace "¿Olvidó su contraseña?" que lleva a la recuperación', (tester) async {
    await _abrirRecuperacion(tester, _api());
    expect(find.byType(RecuperarClavePage), findsOneWidget);
    expect(find.text('Recupere su contraseña'), findsOneWidget);
  });

  testWidgets('un correo vacío o inválido no llama a la API', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);

    await tocarBoton(tester, 'Enviar código');
    expect(find.textContaining('correo'), findsWidgets);
    await escribir(tester, 'Correo electrónico', 'no-es-correo');
    await tocarBoton(tester, 'Enviar código');
    expect(client.rutasSolicitadas, isEmpty);
    expect(find.text('Recupere su contraseña'), findsOneWidget);
  });

  testWidgets('pedir el código pasa al segundo paso y manda el correo sin espacios', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);

    await _pedirCodigo(tester, correo: ' ana@correo.com ');

    expect(client.llamada('POST', '/auth/recuperar-clave').cuerpo, {'correo': 'ana@correo.com'});
    expect(find.text('Cree una contraseña nueva'), findsOneWidget);
    expect(find.textContaining('Si ana@correo.com está registrado'), findsOneWidget); // no afirma que exista
    expect(find.text('Cambiar contraseña'), findsOneWidget);
  });

  testWidgets('si el servidor falla al pedir el código se queda en el primer paso con el motivo', (tester) async {
    final client = _api(extra: {
      'POST /auth/recuperar-clave': const ServerFailure('No se pudo enviar el correo.', statusCode: 503),
    });
    await _abrirRecuperacion(tester, client);

    await _pedirCodigo(tester);

    expect(find.text('Recupere su contraseña'), findsOneWidget);
    expect(find.textContaining('No se pudo enviar el correo.'), findsOneWidget);
  });

  testWidgets('el segundo paso no llama a la API si faltan datos o las contraseñas no coinciden', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);
    await _pedirCodigo(tester);

    await tocarBoton(tester, 'Cambiar contraseña');
    expect(find.text('Ingrese el código que le enviamos.'), findsOneWidget);

    await escribir(tester, 'Código de verificación', '123456');
    await escribir(tester, 'Contraseña nueva', 'Nueva2026');
    await escribir(tester, 'Repita la contraseña', 'Otra2026x');
    await tocarBoton(tester, 'Cambiar contraseña');
    expect(client.rutasSolicitadas, ['POST /auth/recuperar-clave']);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
  });

  testWidgets('una contraseña floja se rechaza antes de llamar a la API', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);
    await _pedirCodigo(tester);

    await _llenarSegundoPaso(tester, password: 'corta');
    await tocarBoton(tester, 'Cambiar contraseña');

    expect(client.rutasSolicitadas, ['POST /auth/recuperar-clave']);
  });

  testWidgets('con el código y la contraseña nueva vuelve al login avisando que ya puede entrar', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);
    await _pedirCodigo(tester);

    await _llenarSegundoPaso(tester);
    await tocarBoton(tester, 'Cambiar contraseña');
    await tester.pumpAndSettle();

    expect(client.llamada('POST', '/auth/restablecer-clave').cuerpo,
        {'correo': 'ana@correo.com', 'codigo': '123456', 'password': 'Nueva2026'});
    expect(client.rutasSolicitadas.where((r) => r == 'POST /auth/login'), isEmpty); // no inicia sesión sola
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(_mensajeListo), findsOneWidget);
  });

  testWidgets('un código incorrecto muestra el mensaje del servidor y se queda en la pantalla', (tester) async {
    final client = _api(extra: {
      'POST /auth/restablecer-clave':
          const ServerFailure('El código no es correcto. Le quedan 4 intentos.', statusCode: 400, codigo: 'datos_invalidos'),
    });
    await _abrirRecuperacion(tester, client);
    await _pedirCodigo(tester);

    await _llenarSegundoPaso(tester, codigo: '000000');
    await tocarBoton(tester, 'Cambiar contraseña');
    await tester.pumpAndSettle();

    expect(find.text('El código no es correcto. Le quedan 4 intentos.'), findsOneWidget);
    expect(find.byType(RecuperarClavePage), findsOneWidget);
    expect(find.text(_mensajeListo), findsNothing);
  });

  testWidgets('reenviar el código espera 60 s y luego pide otro', (tester) async {
    final client = _api();
    await _abrirRecuperacion(tester, client);
    await _pedirCodigo(tester);

    expect(find.text('Reenviar código en 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tocarBoton(tester, 'Reenviar código');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(client.rutasSolicitadas.where((r) => r == 'POST /auth/recuperar-clave').length, 2);
    expect(find.text('Si el correo está registrado, le enviamos un código nuevo.'), findsOneWidget);
    // Se sale de la pantalla para que el reloj termine y no queden temporizadores pendientes.
    await tocarBoton(tester, 'Volver a iniciar sesión');
    await tester.pumpAndSettle();
  });

  testWidgets('"Usar otro correo" vuelve al primer paso y limpia lo escrito', (tester) async {
    await _abrirRecuperacion(tester, _api());
    await _pedirCodigo(tester);
    await _llenarSegundoPaso(tester);

    await tocarBoton(tester, 'Usar otro correo');
    await tester.pumpAndSettle();

    expect(find.text('Recupere su contraseña'), findsOneWidget);
    await _pedirCodigo(tester, correo: 'otra@correo.com');
    expect(tester.widget<TextFormField>(campo('Código de verificación')).controller!.text, isEmpty);
    await tocarBoton(tester, 'Volver a iniciar sesión');
    await tester.pumpAndSettle();
  });

  testWidgets('"Volver a iniciar sesión" regresa al login', (tester) async {
    await _abrirRecuperacion(tester, _api());
    await tocarBoton(tester, 'Volver a iniciar sesión');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
