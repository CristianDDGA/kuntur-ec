import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/app_router.dart';
import 'config/app_theme.dart';
import 'config/providers.dart';

/// Bandera de compilación para suites E2E (Playwright): activa el árbol de
/// semántica al arrancar (`flutter build web --dart-define=ENABLE_SEMANTICS=true`).
/// En uso normal queda desactivada para evitar el bug de foco de `<input>` en Chrome.
const bool _forzarSemanticaE2e = bool.fromEnvironment('ENABLE_SEMANTICS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_forzarSemanticaE2e) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const KunturApp(),
  ));
}

class KunturApp extends ConsumerWidget {
  const KunturApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es', 'EC'),
      supportedLocales: const [
        Locale('es', 'EC'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
