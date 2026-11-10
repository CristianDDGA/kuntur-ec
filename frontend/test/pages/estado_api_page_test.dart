import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/providers.dart';
import 'package:vuelos_app/pages/estado_api_page.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/sistema_service.dart';

import '../helpers/fakes.dart';

Future<void> _pump(WidgetTester tester, FakeRestClient client) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [sistemaServiceProvider.overrideWithValue(SistemaService(client))],
    child: const MaterialApp(home: EstadoApiPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la API conectada', (tester) async {
    await _pump(tester, FakeRestClient(respuesta: healthOk));

    expect(find.text('API conectada: kuntur-ec-api'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('muestra el error y permite reintentar', (tester) async {
    final client = FakeRestClient(error: const NetworkFailure());
    await _pump(tester, client);

    expect(find.textContaining('API no disponible'), findsOneWidget);
    expect(find.textContaining('No se pudo conectar con el servidor.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(client.rutasSolicitadas, ['/health', '/health']);
  });
}
