import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/pages/inicio_page.dart';
import 'package:vuelos_app/pages/registro_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

const _registroOk = {'mensaje': 'Usuario registrado correctamente.', 'usuario': usuarioAna};

RouteFakeRestClient _api({Object? registro = _registroOk, Object? login = respuestaLogin}) =>
    RouteFakeRestClient({'POST /usuarios/registro': registro, 'POST /auth/login': login});

Future<void> _abrirRegistro(WidgetTester tester, RouteFakeRestClient client) async {
  await abrirApp(tester, client: client);
  await tocarBoton(tester, 'Cree una');
  await tester.pumpAndSettle();
  expect(find.byType(RegistroPage), findsOneWidget);
}

Future<void> _llenar(WidgetTester tester, {String nombre = 'Ana Torres', String correo = 'ana@correo.com',
    String password = 'Clave2026', String? confirmacion}) async {
  await escribir(tester, 'Nombre completo', nombre);
  await escribir(tester, 'Correo electrónico', correo);
  await escribir(tester, 'Contraseña', password);
  await escribir(tester, 'Repita la contraseña', confirmacion ?? password);
}

void main() {
  testWidgets('enviar vacío muestra todos los errores y no llama a la API', (tester) async {
    final client = _api();
    await _abrirRegistro(tester, client);

    await tocarBoton(tester, 'Crear cuenta');

    expect(find.text('Ingrese su nombre completo.'), findsOneWidget);
    expect(find.text('Ingrese su correo.'), findsOneWidget);
    expect(find.text('Ingrese una contraseña.'), findsOneWidget);
    expect(find.text('Repita la contraseña.'), findsOneWidget);
    expect(client.llamadas, isEmpty);
  });

  for (final caso in <(String, String, String)>[
    ('emoji', 'Ana 😀', 'Use solo letras'),
    ('números', 'Ana123', 'Use solo letras'),
    ('script', '<script>alert(1)</script>', 'Use solo letras'),
    ('una letra', 'A', 'al menos 2 letras'),
  ]) {
    testWidgets('nombre con ${caso.$1}: se rechaza antes de enviar', (tester) async {
      final client = _api();
      await _abrirRegistro(tester, client);

      await _llenar(tester, nombre: caso.$2);
      await tocarBoton(tester, 'Crear cuenta');

      expect(find.textContaining(caso.$3), findsOneWidget);
      expect(client.llamadas, isEmpty);
    });
  }

  testWidgets('contraseña débil y confirmación distinta', (tester) async {
    final client = _api();
    await _abrirRegistro(tester, client);

    await _llenar(tester, password: 'abc', confirmacion: 'xyz');
    await tocarBoton(tester, 'Crear cuenta');

    expect(find.textContaining('al menos 8 caracteres'), findsWidgets); // error + requisito
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(client.llamadas, isEmpty);
  });

  testWidgets('la lista de requisitos se marca mientras se escribe', (tester) async {
    await _abrirRegistro(tester, _api());

    expect(find.byIcon(Icons.check_circle), findsNothing);
    await escribir(tester, 'Contraseña', 'abc');
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // letras
    await escribir(tester, 'Contraseña', 'abcdefg1');
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
  });

  testWidgets('registro correcto: crea la cuenta, inicia sesión y entra', (tester) async {
    final tokens = InMemoryTokenStorage();
    final client = _api();
    usarPantallaGrande(tester);
    await abrirApp(tester, client: client, tokens: tokens);
    await tocarBoton(tester, 'Cree una');
    await tester.pumpAndSettle();

    await _llenar(tester, nombre: '  Ana   Torres ', correo: ' ana@correo.com ');
    await tocarBoton(tester, 'Crear cuenta');
    await tester.pumpAndSettle();

    expect(client.rutasSolicitadas, ['POST /usuarios/registro', 'POST /auth/login']);
    expect(client.llamada('POST', '/usuarios/registro').cuerpo,
        {'nombre': 'Ana Torres', 'correo': 'ana@correo.com', 'password': 'Clave2026'}); // nombre normalizado
    expect(find.byType(InicioPage), findsOneWidget);
    expect(await tokens.leer(), 'jwt-de-prueba');
  });

  testWidgets('correo repetido (409): muestra el mensaje y no inicia sesión', (tester) async {
    final client = _api(
      registro: const ServerFailure('Ya existe una cuenta registrada con ese correo.',
          statusCode: 409, codigo: 'conflicto'),
    );
    await _abrirRegistro(tester, client);

    await _llenar(tester);
    await tocarBoton(tester, 'Crear cuenta');
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una cuenta registrada con ese correo.'), findsOneWidget);
    expect(client.rutasSolicitadas, ['POST /usuarios/registro']);
    expect(find.byType(RegistroPage), findsOneWidget);
  });

  testWidgets('cuenta creada pero el login automático falla: lo explica', (tester) async {
    final client = _api(login: const NetworkFailure());
    await _abrirRegistro(tester, client);

    await _llenar(tester);
    await tocarBoton(tester, 'Crear cuenta');
    await tester.pumpAndSettle();

    expect(find.textContaining('Su cuenta fue creada'), findsOneWidget);
    expect(find.byType(RegistroPage), findsOneWidget);
  });

  testWidgets('el enlace vuelve al login', (tester) async {
    await _abrirRegistro(tester, _api());

    await tocarBoton(tester, 'Inicie sesión');
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
  });
}
