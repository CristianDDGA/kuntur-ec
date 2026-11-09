import 'package:shared_preferences/shared_preferences.dart';

/// Abstracción del almacenamiento del JWT (principio de Inversión de Dependencias).
abstract interface class TokenStorage {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> eliminar();
}

class SharedPrefsTokenStorage implements TokenStorage {
  static const _key = 'jwt_token';

  @override
  Future<String?> leer() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> guardar(String token) async =>
      (await SharedPreferences.getInstance()).setString(_key, token);

  @override
  Future<void> eliminar() async => (await SharedPreferences.getInstance()).remove(_key);
}
