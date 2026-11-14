import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/widgets/isometric_kuntur.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

Future<void> _abrirMapa(WidgetTester tester) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuarioAna},
    'GET /vuelos': respuestaVuelos,
    'GET /iva': respuestaIva,
    'GET /vuelos/3': vueloQuitoGuayaquil,
    'GET /vuelos/3/asientos': mapaJson(),
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(appRouterProvider)
      .push(AppRoutes.asientosDelVuelo(3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la cabina se dibuja con proa isométrica y encabezado de 6 posiciones', (tester) async {
    await _abrirMapa(tester);

    expect(find.byType(ProaIsometricaAvion), findsOneWidget);
    for (final posicion in ['I', 'II', 'III', 'IV', 'V', 'VI']) {
      expect(find.text(posicion), findsOneWidget, reason: 'falta la posición $posicion');
    }
    expect(find.text('Ventana · Pasillo · Ventana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cabina reparte 6 asientos por fila visual (3 + pasillo + 3)', (tester) async {
    await _abrirMapa(tester);

    // Fila visual 1 con contrato A-D: 1A, 1B, 1C, 1D, 2A, 2B.
    final filaUno = ['1A', '1B', '1C', '1D', '2A', '2B'];
    final alturas = filaUno.map((asiento) => tester.getCenter(find.text(asiento)).dy).toList();
    for (final altura in alturas) {
      expect(altura, closeTo(alturas.first, 1.5), reason: 'los 6 asientos deben compartir la misma fila');
    }

    // La fila visual 2 empieza más abajo (2C, 2D, 3A…).
    final filaDos = tester.getCenter(find.text('2C')).dy;
    expect(filaDos, greaterThan(alturas.first + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el contrato A-D del backend se conserva en el mapa', (tester) async {
    await _abrirMapa(tester);

    for (final asiento in ['1A', '1B', '1C', '1D']) {
      expect(find.text(asiento), findsOneWidget);
    }
  });

  testWidgets('en una pantalla de 340 px de ancho no hay RenderFlex overflow', (tester) async {
    final client = RouteFakeRestClient({
      'GET /auth/perfil': {'usuario': usuarioAna},
      'GET /vuelos': respuestaVuelos,
      'GET /iva': respuestaIva,
      'GET /vuelos/3': vueloQuitoGuayaquil,
      'GET /vuelos/3/asientos': mapaJson(),
    });
    await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
    tester.view.physicalSize = const Size(340, 800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(appRouterProvider)
        .push(AppRoutes.asientosDelVuelo(3));
    await tester.pumpAndSettle();

    // La barra de resumen siempre está montada (fuera del ListView).
    expect(find.text('Asientos (0 de 10): Ninguno'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
