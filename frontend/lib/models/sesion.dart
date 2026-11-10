import '../services/api_exception.dart';
import '../services/rest_client.dart';
import 'usuario.dart';

/// Respuesta de `POST /api/auth/login`: {"token", "tipo": "Bearer", "expira", "usuario": {...}}.
class Sesion {
  const Sesion({required this.token, required this.expira, required this.usuario});

  factory Sesion.fromJson(JsonMap json) {
    final token = json['token'];
    final expira = DateTime.tryParse(json['expira']?.toString() ?? '');
    final usuario = json['usuario'];
    if (token is! String || token.isEmpty || expira == null || usuario is! JsonMap) {
      throw const InvalidResponseFailure();
    }
    return Sesion(token: token, expira: expira, usuario: Usuario.fromJson(usuario));
  }

  final String token;
  final DateTime expira;
  final Usuario usuario;
}
