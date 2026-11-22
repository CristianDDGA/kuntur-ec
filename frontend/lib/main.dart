import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/app_router.dart';
import 'config/app_theme.dart';
import 'config/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Accesibilidad en la web: NO se fuerza el árbol de semántica al arrancar (`ensureSemantics`). Forzarlo hace que
  // cada campo de texto pase por un <input> de semántica y en Chrome el primer clic a veces enfoca el campo sin dejar
  // escribir hasta pasar a otro y volver. Flutter la activa sola cuando hace falta (lector de pantalla o el botón
  // «Enable accessibility» que ofrece al teclado), y las etiquetas (`Semantics`) siguen en los widgets.
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
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
