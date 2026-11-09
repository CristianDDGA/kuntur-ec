/// Configuración global. La URL de la API se puede cambiar sin tocar código:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  static const Duration requestTimeout = Duration(seconds: 15);
  static const String appName = 'Reservas de Vuelos';
}
