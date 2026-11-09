import 'package:shared_preferences/shared_preferences.dart';

/// Abstracción del almacenamiento del JWT (principio de Inversión de Dependencias).
abstract interface class TokenStorage {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> eliminar();
}

/// Implementación con SharedPreferences (localStorage en web).
/// La instancia se inyecta para poder sustituirla en pruebas.
class SharedPrefsTokenStorage implements TokenStorage {
  SharedPrefsTokenStorage(this._prefs);

  static const _key = 'jwt_token';
  final SharedPreferences _prefs;

  @override
  Future<String?> leer() async => _prefs.getString(_key);

  @override
  Future<void> guardar(String token) async => _prefs.setString(_key, token);

  @override
  Future<void> eliminar() async => _prefs.remove(_key);
}
