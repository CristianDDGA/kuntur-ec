import '../models/sesion.dart';
import '../models/usuario.dart';
import 'api_exception.dart';
import 'rest_client.dart';
import 'token_storage.dart';

/// Consume los servicios de Usuarios y Autenticación de la API
/// (`/usuarios/registro`, `/auth/login`, `/auth/perfil`, `/auth/logout`).
class AuthService {
  const AuthService(this._client, this._tokens);

  final RestClient _client;
  final TokenStorage _tokens;

  /// Inicia sesión y guarda el JWT para que `HttpRestClient` lo envíe en las siguientes peticiones.
  Future<Sesion> login({required String correo, required String password}) async {
    final json = asJsonMap(await _client.post(
      '/auth/login',
      body: {'correo': correo.trim(), 'password': password},
    ));
    final sesion = Sesion.fromJson(json);
    await _tokens.guardar(sesion.token);
    return sesion;
  }

  /// Crea una cuenta de cliente. No inicia sesión: eso lo decide el controlador.
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final json = asJsonMap(await _client.post(
      '/usuarios/registro',
      body: {'nombre': nombre, 'correo': correo.trim(), 'password': password},
    ));
    final usuario = json['usuario'];
    if (usuario is! JsonMap) throw const InvalidResponseFailure();
    return Usuario.fromJson(usuario);
  }

  /// Usuario dueño del token guardado. Lanza [UnauthorizedFailure] si el token venció o fue revocado.
  Future<Usuario> perfil() async {
    final json = asJsonMap(await _client.get('/auth/perfil'));
    final usuario = json['usuario'];
    if (usuario is! JsonMap) throw const InvalidResponseFailure();
    return Usuario.fromJson(usuario);
  }

  Future<bool> tieneToken() async => (await _tokens.leer()) != null;

  /// Cierra la sesión en el servidor (revoca el token). Aunque el servidor no responda,
  /// el token local se elimina siempre: el usuario no puede quedar "atrapado" en la sesión.
  Future<void> cerrarSesion() async {
    try {
      await _client.post('/auth/logout');
    } on Failure {
      // Sin conexión o token ya inválido: da igual, la sesión local se borra de todos modos.
    } finally {
      await _tokens.eliminar();
    }
  }

  /// Borra el token local sin avisar al servidor (token vencido).
  Future<void> descartarToken() => _tokens.eliminar();
}
