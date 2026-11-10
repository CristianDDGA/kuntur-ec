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

  group('registrar', () {
    test('devuelve el usuario creado y envía los datos tal cual', () async {
      final client = RouteFakeRestClient({'POST /usuarios/registro': {'mensaje': 'ok', 'usuario': usuarioAna}});

      final usuario = await _servicio(client).registrar(
        nombre: 'Ana Torres',
        correo: ' ana@correo.com ',
        password: 'Clave2026',
      );

      expect(usuario.rol, Rol.cliente);
      expect(client.llamada('POST', '/usuarios/registro').cuerpo,
          {'nombre': 'Ana Torres', 'correo': 'ana@correo.com', 'password': 'Clave2026'});
    });

    test('un correo repetido llega como ServerFailure 409 con el mensaje de la API', () async {
      final client = RouteFakeRestClient({
        'POST /usuarios/registro': const ServerFailure('Ya existe una cuenta registrada con ese correo.',
            statusCode: 409, codigo: 'conflicto'),
      });
      await expectLater(
        _servicio(client).registrar(nombre: 'Ana', correo: 'ana@correo.com', password: 'Clave2026'),
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
