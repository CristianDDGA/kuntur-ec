/// Configuración global. La URL de la API se puede cambiar sin tocar código:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  /// ID de cliente OAuth web de Google (no es secreto; el servidor valida el id_token contra este mismo ID).
  /// Vacío = el botón de Google no se muestra:  --dart-define=GOOGLE_CLIENT_ID=
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '804537826653-ti79nuv63v45qh8ods48nut3ckfrm9n9.apps.googleusercontent.com',
  );

  static const Duration requestTimeout = Duration(seconds: 15);
  static const String appName = 'Kuntur EC';
}
