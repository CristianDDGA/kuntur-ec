import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuelos_app/core/storage/token_storage.dart';

void main() {
  test('guarda, lee y elimina el token', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedPrefsTokenStorage(await SharedPreferences.getInstance());

    expect(await storage.leer(), isNull);
    await storage.guardar('jwt-123');
    expect(await storage.leer(), 'jwt-123');
    await storage.eliminar();
    expect(await storage.leer(), isNull);
  });
}
