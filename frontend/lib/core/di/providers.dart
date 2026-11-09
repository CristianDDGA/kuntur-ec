import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../network/http_rest_client.dart';
import '../network/rest_client.dart';
import '../storage/token_storage.dart';

/// Composition root del frontend: único lugar donde se crean las dependencias
/// concretas de `core`. Cada feature declara las suyas en
/// `features/<feature>/presentation/providers/`.

/// Se sobrescribe en `main()` con la instancia ya inicializada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider debe sobrescribirse en main().'),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SharedPrefsTokenStorage(ref.watch(sharedPreferencesProvider)),
);

final restClientProvider = Provider<RestClient>(
  (ref) => HttpRestClient(
    httpClient: ref.watch(httpClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);
