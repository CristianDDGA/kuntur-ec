import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/pages/inicio_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/widgets/boton_degradado.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

RouteFakeRestClient _api(Object? login) => RouteFakeRestClient({'POST /auth/login': login});

void main() {
  testWidgets('sin token se muestra el login', (tester) async {
    await abrirApp(tester, client: _api(respuestaLogin));

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Kuntur '), findsNothing); // la marca es un Text.rich
    expect(find.textContaining('Kuntur'), findsWidgets);
  });

  testWidgets('enviar vacío muestra los errores y no llama a la API', (tester) async {
    final client = _api(respuestaLogin);
    await abrirApp(tester, client: client);

    await tocarBoton(tester, 'Iniciar sesión');

    expect(find.text('Ingrese su correo.'), findsOneWidget);
    expect(find.text('Ingrese su contraseña.'), findsOneWidget);
    expect(client.llamadas, isEmpty);
  });

  testWidgets('un correo mal escrito se corrige antes de enviar', (tester) async {
    final client = _api(respuestaLogin);
    await abrirApp(tester, client: client);

    await escribir(tester, 'Correo electrónico', 'ana-sin-arroba');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');

    expect(find.textContaining('correo válido'), findsOneWidget);
    expect(client.llamadas, isEmpty);
  });

  testWidgets('con credenciales correctas abre la sesión y guarda el token', (tester) async {
    final tokens = InMemoryTokenStorage();
    final client = _api(respuestaLogin);
    await abrirApp(tester, client: client, tokens: tokens);

    await escribir(tester, 'Correo electrónico', '  ana@correo.com ');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(client.llamada('POST', '/auth/login').cuerpo, {'correo': 'ana@correo.com', 'password': 'Clave2026'});
    expect(find.byType(InicioPage), findsOneWidget);
    expect(find.text('Hola, Ana Torres'), findsOneWidget);
    expect(await tokens.leer(), 'jwt-de-prueba');
  });

  testWidgets('Enter en la contraseña también envía el formulario', (tester) async {
    final client = _api(respuestaLogin);
    await abrirApp(tester, client: client);

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(InicioPage), findsOneWidget);
  });

  testWidgets('credenciales incorrectas: muestra el mensaje de la API y sigue en el login', (tester) async {
    final client = _api(const UnauthorizedFailure('Correo o contraseña incorrectos.'));
    await abrirApp(tester, client: client);

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Incorrecta1');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.widget<BotonDegradado>(find.byType(BotonDegradado)).onPressed, isNotNull); // puede reintentar
  });

  testWidgets('demasiados intentos (429): muestra el aviso del servidor', (tester) async {
    final client = _api(const ServerFailure('Demasiados intentos fallidos. Espere antes de volver a intentarlo.',
        statusCode: 429, codigo: 'demasiados_intentos'));
    await abrirApp(tester, client: client);

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Incorrecta1');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.textContaining('Demasiados intentos fallidos'), findsOneWidget);
  });

  testWidgets('sin conexión: mensaje claro, sin detalles técnicos', (tester) async {
    await abrirApp(tester, client: _api(const NetworkFailure()));

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
  });

  testWidgets('una excepción inesperada se oculta tras un mensaje genérico', (tester) async {
    await abrirApp(tester, client: _api(StateError('detalle interno secreto')));

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(find.text('Ocurrió un error inesperado. Intente nuevamente.'), findsOneWidget);
    expect(find.textContaining('secreto'), findsNothing);
  });

  testWidgets('mientras envía: muestra carga, desactiva los campos y evita el doble envío', (tester) async {
    final espera = Completer<Object?>();
    final client = _api((_) => espera.future);
    await abrirApp(tester, client: client);

    await escribir(tester, 'Correo electrónico', 'ana@correo.com');
    await escribir(tester, 'Contraseña', 'Clave2026');
    await tocarBoton(tester, 'Iniciar sesión');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextFormField>(campo('Correo electrónico')).enabled, isFalse);
    await tester.tap(find.byType(BotonDegradado), warnIfMissed: false);
    await tester.pump();
    expect(client.llamadas.length, 1); // el segundo toque no envió otra petición

    espera.complete(respuestaLogin);
    await tester.pumpAndSettle();
    expect(find.byType(InicioPage), findsOneWidget);
  });

  testWidgets('el botón del ojo muestra y oculta la contraseña', (tester) async {
    await abrirApp(tester, client: _api(respuestaLogin));

    bool oculta() => tester.widget<EditableText>(
          find.descendant(of: campo('Contraseña'), matching: find.byType(EditableText)),
        ).obscureText;

    expect(oculta(), isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(oculta(), isFalse);
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(oculta(), isTrue);
  });

  testWidgets('el enlace lleva al registro', (tester) async {
    await abrirApp(tester, client: _api(respuestaLogin));

    await tocarBoton(tester, 'Cree una');
    await tester.pumpAndSettle();

    expect(find.text('Cree su cuenta'), findsOneWidget);
  });
}
