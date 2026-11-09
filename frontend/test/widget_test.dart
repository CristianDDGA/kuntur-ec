import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/core/config/app_config.dart';
import 'package:vuelos_app/core/di/providers.dart';
import 'package:vuelos_app/core/error/failures.dart';
import 'package:vuelos_app/core/network/api_client.dart';
import 'package:vuelos_app/core/storage/token_storage.dart';
import 'package:vuelos_app/main.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<String?> leer() async => null;
  @override
  Future<void> guardar(String token) async {}
  @override
  Future<void> eliminar() async {}
}

class _OfflineApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.error(const NetworkFailure());
}

void main() {
  testWidgets('La app arranca y muestra el estado de la API', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        apiClientProvider.overrideWithValue(_OfflineApiClient()),
      ],
      child: const VuelosApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text(AppConfig.appName), findsOneWidget);
    expect(find.textContaining('API no disponible'), findsOneWidget);
  });
}
