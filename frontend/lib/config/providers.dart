import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/http_rest_client.dart';
import '../services/iva_service.dart';
import '../services/rest_client.dart';
import '../services/sistema_service.dart';
import '../services/token_storage.dart';
import '../services/vuelo_service.dart';
import 'app_config.dart';

/// Inyección de dependencias: único lugar donde se crean los servicios.
/// Las páginas y controladores los obtienen con `ref.watch(...)`, y las
/// pruebas los reemplazan con `overrides`.

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

// ---- Servicios (uno por servicio SOA de la API) ----

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(restClientProvider), ref.watch(tokenStorageProvider)),
);

final sistemaServiceProvider = Provider<SistemaService>(
  (ref) => SistemaService(ref.watch(restClientProvider)),
);

final vueloServiceProvider = Provider<VueloService>(
  (ref) => VueloService(ref.watch(restClientProvider)),
);

final ivaServiceProvider = Provider<IvaService>(
  (ref) => IvaService(ref.watch(restClientProvider)),
);
