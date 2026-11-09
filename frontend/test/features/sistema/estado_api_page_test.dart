import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/core/error/failures.dart';
import 'package:vuelos_app/features/sistema/domain/entities/estado_servicio.dart';
import 'package:vuelos_app/features/sistema/domain/repositories/sistema_repository.dart';
import 'package:vuelos_app/features/sistema/presentation/pages/estado_api_page.dart';
import 'package:vuelos_app/features/sistema/presentation/providers/sistema_providers.dart';

class _FakeSistemaRepository implements SistemaRepository {
  _FakeSistemaRepository({this.estado, this.failure});
  final EstadoServicio? estado;
  final Failure? failure;

  @override
  Future<EstadoServicio> consultarEstado() async => failure != null ? throw failure! : estado!;
}

Future<void> _pump(WidgetTester tester, SistemaRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [sistemaRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: EstadoApiPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la API conectada', (tester) async {
    await _pump(
      tester,
      _FakeSistemaRepository(
        estado: EstadoServicio(servicio: 'kuntur-ec-api', disponible: true, hora: DateTime(2026)),
      ),
    );
    expect(find.text('API conectada: kuntur-ec-api'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('muestra el error cuando la API no responde', (tester) async {
    await _pump(tester, _FakeSistemaRepository(failure: const NetworkFailure()));
    expect(find.textContaining('API no disponible'), findsOneWidget);
    expect(find.textContaining('No se pudo conectar con el servidor.'), findsOneWidget);
  });
}
