import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';
import '../storage/token_storage.dart';

/// Composition root del frontend: aquí se crean las dependencias concretas.
/// Cada feature agregará sus providers (datasource -> repository -> usecase)
/// en `features/<feature>/presentation/providers/`.

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => SharedPrefsTokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    httpClient: ref.watch(httpClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);
