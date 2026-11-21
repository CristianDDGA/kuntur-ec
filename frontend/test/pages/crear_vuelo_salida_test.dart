import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/crear_vuelo_page.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

/// Abre la app como administrador y entra al formulario de nuevo vuelo.
Future<void> _abrirFormulario(WidgetTester tester) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuarioAdmin},
    'GET /vuelos': sinVuelos,
    'GET /aviones': listaAviones,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(appRouterProvider)
      .push(AppRoutes.nuevoVuelo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('salir con datos escritos pide confirmación antes de perder el formulario', (tester) async {
    await _abrirFormulario(tester);
    expect(find.byType(CrearVueloPage), findsOneWidget);

    await escribir(tester, 'Origen', 'Quito');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir sin crear el vuelo?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(find.byType(CrearVueloPage), findsOneWidget);
  });

  testWidgets('salir sin datos vuelve directo, sin preguntar', (tester) async {
    await _abrirFormulario(tester);
    expect(find.byType(CrearVueloPage), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir sin crear el vuelo?'), findsNothing);
    expect(find.byType(CrearVueloPage), findsNothing);
  });
}
