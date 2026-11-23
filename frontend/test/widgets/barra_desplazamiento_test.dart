import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/widgets/kuntur_scaffold.dart';

/// En web y escritorio Flutter no conecta las listas al controlador principal de la ruta (solo en
/// Android/iOS). La barra de desplazamiento de [KunturScaffold] usa ese controlador: si la lista no
/// se conecta, cada scroll lanza "The Scrollbar's ScrollController has no ScrollPosition attached".
void main() {
  for (final plataforma in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux, TargetPlatform.android]) {
    testWidgets('la barra de desplazamiento funciona en ${plataforma.name}', (tester) async {
      debugDefaultTargetPlatformOverride = plataforma;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: KunturScaffold(
            body: ListView(children: [for (var i = 0; i < 80; i++) SizedBox(height: 60, child: Text('Fila $i'))]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fila 0'), findsNothing); // sí se desplazó
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
