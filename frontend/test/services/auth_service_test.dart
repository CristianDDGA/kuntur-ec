import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/usuario.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/auth_service.dart';

import '../helpers/fakes.dart';

AuthService _servicio(RouteFakeRestClient client, [InMemoryTokenStorage? tokens]) =>
    AuthService(client, tokens ?? InMemoryTokenStorage());

void main() {
  group('login', () {
    test('envía el correo sin espacios y guarda el token', () async {
      final client = RouteFakeRestClient({'POST /auth/login': respuestaLogin});
      final tokens = InMemoryTokenStorage();

      final sesion = await _servicio(client, tokens).login(correo: '  ana@correo.com ', password: 'Clave2026');

      expect(client.llamada('POST', '/auth/login').cuerpo, {'correo': 'ana@correo.com', 'password': 'Clave2026'});
      expect(sesion.usuario.nombre, 'Ana Torres');
      expect(await tokens.leer(), 'jwt-de-prueba');
    });

    test('si falla no guarda ningún token y propaga el error de la API', () async {
      final client = RouteFakeRestClient({
        'POST /auth/login': const UnauthorizedFailure('Correo o contraseña incorrectos.'),
      });
      final tokens = InMemoryTokenStorage();

      await expectLater(
        _servicio(client, tokens).login(correo: 'ana@correo.com', password: 'mala'),
        throwsA(isA<UnauthorizedFailure>().having((e) => e.mensaje, 'mensaje', 'Correo o contraseña incorrectos.')),
      );
      expect(await tokens.leer(), isNull);
    });

    test('una respuesta sin token lanza InvalidResponseFailure', () async {
      final client = RouteFakeRestClient({'POST /auth/login': {'tipo': 'Bearer'}});
      await expectLater(
        _servicio(client).login(correo: 'a@b.com', password: 'x'),
        throwsA(isA<InvalidResponseFailure>()),
      );
    });
  });

  group('Google y cédula', () {
    test('loginGoogle envía solo el id_token y guarda el JWT de la sesión', () async {
      final tokens = InMemoryTokenStorage();
      final client = RouteFakeRestClient({'POST /auth/google': {...respuestaLogin, 'nuevo': true}});
      final sesion = await AuthService(client, tokens).loginGoogle('id-token');

      expect(client.llamada('POST', '/auth/google').cuerpo, {'id_token': 'id-token'});
      expect(sesion.usuario.correo, 'ana@correo.com');
      expect(await tokens.leer(), 'jwt-de-prueba');
    });

    test('un token que el servidor rechaza no deja sesión guardada', () async {
      final tokens = InMemoryTokenStorage();
      final client = RouteFakeRestClient({'POST /auth/google': const UnauthorizedFailure('No se pudo validar su cuenta de Google.')});
      await expectLater(AuthService(client, tokens).loginGoogle('malo'), throwsA(isA<UnauthorizedFailure>()));
      expect(await tokens.leer(), isNull);
    });

    test('completarCedula usa PUT, recorta la cédula y devuelve el usuario con ella', () async {
      final client = RouteFakeRestClient({'PUT /usuarios/cedula': {'mensaje': 'ok', 'usuario': usuarioAna}});
      final usuario = await _servicio(client).completarCedula(' 1710034065 ');

      expect(client.llamada('PUT', '/usuarios/cedula').cuerpo, {'cedula': '1710034065'});
      expect(usuario.cedula, '1710034065');
    });

    test('un usuario sin cédula en la respuesta queda con cedula nula', () {
      final sin = {...usuarioAna}..remove('cedula');
      expect(Usuario.fromJson(sin).cedula, isNull);
    });
  });

  group('recuperar la contraseña', () {
    test('solicitarRecuperacion manda solo el correo, sin espacios', () async {
      final client = RouteFakeRestClient({'POST /auth/recuperar-clave': {'mensaje': 'ok'}});
      await _servicio(client).solicitarRecuperacion(correo: ' ana@correo.com ');
      expect(client.llamada('POST', '/auth/recuperar-clave').cuerpo, {'correo': 'ana@correo.com'});
    });

    test('restablecerClave envía correo y código recortados, y la contraseña tal cual', () async {
      final client = RouteFakeRestClient({'POST /auth/restablecer-clave': {'mensaje': 'ok'}});
      await _servicio(client).restablecerClave(correo: ' ana@correo.com ', codigo: ' 123456 ', password: ' Nueva2026 ');
      expect(client.llamada('POST', '/auth/restablecer-clave').cuerpo,
          {'correo': 'ana@correo.com', 'codigo': '123456', 'password': ' Nueva2026 '});
    });

    test('restablecerClave no inicia sesión ni guarda ningún token', () async {
      final client = RouteFakeRestClient({'POST /auth/restablecer-clave': {'mensaje': 'ok'}});
      final tokens = InMemoryTokenStorage();
      await _servicio(client, tokens).restablecerClave(correo: 'ana@correo.com', codigo: '123456', password: 'Nueva2026');
      expect(await tokens.leer(), isNull);
    });

    test('un código malo llega como ServerFailure 400 con el mensaje de la API', () {
      final client = RouteFakeRestClient({
        'POST /auth/restablecer-clave': const ServerFailure('El código no es correcto. Le quedan 4 intentos.', statusCode: 400),
      });
      expect(
        _servicio(client).restablecerClave(correo: 'ana@correo.com', codigo: '000000', password: 'Nueva2026'),
        throwsA(isA<ServerFailure>().having((e) => e.mensaje, 'mensaje', contains('Le quedan 4'))),
      );
    });
  });

  group('verificar el correo', () {
    test('verificarCorreo envía correo y código recortados', () async {
      final client = RouteFakeRestClient({'POST /auth/verificar-correo': {'mensaje': 'ok', 'correo': 'ana@correo.com'}});
      await _servicio(client).verificarCorreo(correo: ' ana@correo.com ', codigo: ' 123456 ');
      expect(client.llamada('POST', '/auth/verificar-correo').cuerpo, {'correo': 'ana@correo.com', 'codigo': '123456'});
    });

    test('un código malo llega como ServerFailure 400 con el mensaje de la API', () {
      final client = RouteFakeRestClient({
        'POST /auth/verificar-correo': const ServerFailure('El código no es correcto. Le quedan 4 intentos.', statusCode: 400),
      });
      expect(
        _servicio(client).verificarCorreo(correo: 'ana@correo.com', codigo: '000000'),
        throwsA(isA<ServerFailure>().having((e) => e.mensaje, 'mensaje', contains('Le quedan 4'))),
      );
    });

    test('reenviarCodigo manda solo el correo', () async {
      final client = RouteFakeRestClient({'POST /auth/reenviar-codigo': {'mensaje': 'ok'}});
      await _servicio(client).reenviarCodigo(correo: ' ana@correo.com ');
      expect(client.llamada('POST', '/auth/reenviar-codigo').cuerpo, {'correo': 'ana@correo.com'});
    });

    test('si el correo del registro no salió, codigoEnviado es false', () async {
      final client = RouteFakeRestClient({
        'POST /usuarios/registro': {'mensaje': 'ok', 'usuario': usuarioAna, 'verificacion_pendiente': true, 'codigo_enviado': false},
      });
      final r = await _servicio(client).registrar(nombre: 'Ana', cedula: '1710034065', correo: 'ana@correo.com', password: 'Clave2026');
      expect(r.codigoEnviado, isFalse);
    });
  });

  group('registrar', () {
    test('devuelve el usuario creado y envía los datos tal cual', () async {
      final client = RouteFakeRestClient({'POST /usuarios/registro': {'mensaje': 'ok', 'usuario': usuarioAna}});

      final usuario = await _servicio(client).registrar(
        nombre: 'Ana Torres',
        cedula: ' 1710034065 ',
        correo: ' ana@correo.com ',
        password: 'Clave2026',
      );

      expect(usuario.usuario.rol, Rol.cliente);
      expect(usuario.codigoEnviado, isTrue);
      expect(client.llamada('POST', '/usuarios/registro').cuerpo,
          {'nombre': 'Ana Torres', 'cedula': '1710034065', 'correo': 'ana@correo.com', 'password': 'Clave2026'});
    });

    test('un correo repetido llega como ServerFailure 409 con el mensaje de la API', () async {
      final client = RouteFakeRestClient({
        'POST /usuarios/registro': const ServerFailure('Ya existe una cuenta registrada con ese correo.',
            statusCode: 409, codigo: 'conflicto'),
      });
      await expectLater(
        _servicio(client).registrar(nombre: 'Ana', cedula: '1710034065', correo: 'ana@correo.com', password: 'Clave2026'),
        throwsA(isA<ServerFailure>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  test('perfil lee el usuario del token', () async {
    final client = RouteFakeRestClient({'GET /auth/perfil': {'usuario': usuarioAna}});
    expect((await _servicio(client).perfil()).correo, 'ana@correo.com');
  });

  group('cerrarSesion', () {
    test('avisa al servidor y borra el token', () async {
      final client = RouteFakeRestClient({'POST /auth/logout': {'mensaje': 'ok'}});
      final tokens = InMemoryTokenStorage('jwt');
      await _servicio(client, tokens).cerrarSesion();
      expect(client.rutasSolicitadas, ['POST /auth/logout']);
      expect(await tokens.leer(), isNull);
    });

    for (final fallo in <Failure>[const NetworkFailure(), const UnauthorizedFailure()]) {
      test('borra el token aunque el servidor falle (${fallo.runtimeType})', () async {
        final client = RouteFakeRestClient({'POST /auth/logout': fallo});
        final tokens = InMemoryTokenStorage('jwt');
        await _servicio(client, tokens).cerrarSesion();
        expect(await tokens.leer(), isNull);
      });
    }
  });

  test('tieneToken y descartarToken', () async {
    final tokens = InMemoryTokenStorage('jwt');
    final servicio = _servicio(RouteFakeRestClient({}), tokens);
    expect(await servicio.tieneToken(), isTrue);
    await servicio.descartarToken();
    expect(await servicio.tieneToken(), isFalse);
  });
}
