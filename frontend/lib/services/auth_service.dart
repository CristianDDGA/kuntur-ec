import '../models/sesion.dart';
import '../models/usuario.dart';
import 'api_exception.dart';
import 'rest_client.dart';
import 'token_storage.dart';

/// Cuenta recién creada y si el correo con el código salió.
class ResultadoRegistro {
  const ResultadoRegistro({required this.usuario, required this.codigoEnviado});

  final Usuario usuario;
  final bool codigoEnviado;
}

/// Consume los servicios de Usuarios y Autenticación de la API
/// (`/usuarios/registro`, `/auth/login`, `/auth/perfil`, `/auth/logout`, recuperación de contraseña).
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

  /// Crea una cuenta de cliente (sin verificar). No inicia sesión: antes hay que confirmar el correo con el código
  /// que llega por correo ([verificarCorreo]).
  Future<ResultadoRegistro> registrar({
    required String nombre,
    required String cedula,
    required String correo,
    required String password,
  }) async {
    final json = asJsonMap(await _client.post(
      '/usuarios/registro',
      body: {'nombre': nombre, 'cedula': cedula.trim(), 'correo': correo.trim(), 'password': password},
    ));
    final usuario = json['usuario'];
    if (usuario is! JsonMap) throw const InvalidResponseFailure();
    // `codigo_enviado` es false si el correo no salió: la persona puede pedir otro código en la pantalla de verificación.
    return ResultadoRegistro(usuario: Usuario.fromJson(usuario), codigoEnviado: json['codigo_enviado'] != false);
  }

  /// `POST /auth/google`: inicia sesión con el `id_token` que entregó Google. El servidor lo valida; si la cuenta no
  /// existe la crea (con el correo ya verificado y sin cédula). Guarda el JWT igual que [login].
  Future<Sesion> loginGoogle(String idToken) async {
    final json = asJsonMap(await _client.post('/auth/google', body: {'id_token': idToken}));
    final sesion = Sesion.fromJson(json);
    await _tokens.guardar(sesion.token);
    return sesion;
  }

  /// `PUT /usuarios/cedula`: guarda la cédula de una cuenta que no la tiene (y opcionalmente su nombre editado).
  Future<Usuario> completarCedula(String cedula, {String? nombre}) async {
    final body = <String, dynamic>{'cedula': cedula.trim()};
    if (nombre != null && nombre.trim().isNotEmpty) {
      body['nombre'] = nombre.trim();
    }
    final json = asJsonMap(await _client.put('/usuarios/cedula', body: body));
    final usuario = json['usuario'];
    if (usuario is! JsonMap) throw const InvalidResponseFailure();
    return Usuario.fromJson(usuario);
  }

  /// `POST /auth/verificar-correo`: confirma el correo con el código de 6 dígitos.
  Future<void> verificarCorreo({required String correo, required String codigo}) async {
    asJsonMap(await _client.post('/auth/verificar-correo', body: {'correo': correo.trim(), 'codigo': codigo.trim()}));
  }

  /// `POST /auth/reenviar-codigo`: pide un código nuevo. Responde igual exista o no la cuenta.
  Future<void> reenviarCodigo({required String correo}) async {
    asJsonMap(await _client.post('/auth/reenviar-codigo', body: {'correo': correo.trim()}));
  }

  /// `POST /auth/recuperar-clave`: pide el código para restablecer la contraseña. Responde igual exista o no la cuenta.
  Future<void> solicitarRecuperacion({required String correo}) async {
    asJsonMap(await _client.post('/auth/recuperar-clave', body: {'correo': correo.trim()}));
  }

  /// `POST /auth/restablecer-clave`: guarda la contraseña nueva si el código de 6 dígitos es correcto. No inicia
  /// sesión: el servidor cierra las sesiones abiertas y la persona entra con la contraseña nueva.
  Future<void> restablecerClave({required String correo, required String codigo, required String password}) async {
    asJsonMap(await _client.post(
      '/auth/restablecer-clave',
      body: {'correo': correo.trim(), 'codigo': codigo.trim(), 'password': password},
    ));
  }

  /// Usuario dueño del token guardado. Lanza [UnauthorizedFailure] si el token venció o fue revocado.
  Future<Usuario> perfil() async {
    final json = asJsonMap(await _client.get('/auth/perfil'));
    final usuario = json['usuario'];
    if (usuario is! JsonMap) throw const InvalidResponseFailure();
    return Usuario.fromJson(usuario);
  }

  Future<bool> tieneToken() async => (await _tokens.leer()) != null;

  /// El token guardado (para saber cuándo vence), o `null` si no hay.
  Future<String?> tokenGuardado() => _tokens.leer();

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
