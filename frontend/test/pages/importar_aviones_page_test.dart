import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/controllers/aviones_controller.dart';
import 'package:vuelos_app/pages/importar_aviones_page.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

const _csv = 'matricula;modelo;filas\nHC-ABC;Airbus A320;30\n';

const _revision = {
  'total_filas': 1,
  'nuevos': 1,
  'existentes': [],
  'con_errores': 0,
  'errores': [],
  'vista_previa': [
    {'linea': 2, 'matricula': 'HC-ABC', 'modelo': 'Airbus A320', 'filas': 30, 'capacidad': 120, 'ya_existe': false},
  ],
};

/// Abre la app como administrador en la pantalla de importación. El selector de archivos del sistema no se
/// puede abrir en una prueba: se entrega el contenido al controlador, igual que lo haría la pantalla.
Future<(RouteFakeRestClient, ProviderContainer)> _abrir(WidgetTester tester, Map<String, Object?> rutas,
    {Object usuario = usuarioAdmin}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': sinVuelos,
    'GET /aviones': {'total': 0, 'aviones': []},
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  container.read(appRouterProvider).push(AppRoutes.importarAviones);
  await tester.pumpAndSettle();
  return (client, container);
}

void main() {
  testWidgets('un cliente no puede abrir la importación: vuelve a la lista', (tester) async {
    await _abrir(tester, {}, usuario: usuarioAna);
    expect(find.byType(ImportarAvionesPage), findsNothing);
  });

  testWidgets('muestra las instrucciones y que aún no hay aviones', (tester) async {
    await _abrir(tester, {});
    expect(find.byType(ImportarAvionesPage), findsOneWidget);
    expect(find.textContaining('matricula;modelo;filas'), findsOneWidget);
    expect(find.text('Aún no hay aviones'), findsOneWidget);
    expect(find.text('Elegir archivo CSV'), findsOneWidget);
  });

  testWidgets('un archivo correcto se revisa sin guardar y luego se importa', (tester) async {
    final (api, container) = await _abrir(tester, {
      'POST /aviones/importacion/validar': _revision,
      'POST /aviones/importacion': {'mensaje': 'ok', 'creados': 1, 'omitidos': [], 'total_filas': 1},
    });

    await container.read(importarAvionesControllerProvider.notifier).elegirArchivo('flota.csv', _csv);
    await tester.pumpAndSettle();

    expect(find.text('Archivo: flota.csv'), findsOneWidget);
    expect(find.textContaining('Archivo correcto: 1 avión nuevo'), findsOneWidget);
    expect(find.text('HC-ABC · Airbus A320'), findsOneWidget);
    expect(api.llamadas.where((l) => l.ruta == '/aviones/importacion'), isEmpty); // revisar no guarda

    await tester.ensureVisible(find.text('Importar 1 avión'));
    await tocarBoton(tester, 'Importar 1 avión');
    await tester.pumpAndSettle();

    expect(find.textContaining('Se importaron 1 avión'), findsOneWidget);
    expect(api.llamada('POST', '/aviones/importacion').cuerpo, _csv);
  });

  testWidgets('con errores lista cada línea y no deja importar', (tester) async {
    final (api, container) = await _abrir(tester, {
      'POST /aviones/importacion/validar': {
        ..._revision,
        'nuevos': 0,
        'con_errores': 1,
        'errores': [{'linea': 3, 'mensaje': 'Las filas deben ser un entero entre 1 y 50.'}],
        'vista_previa': [],
      },
    });

    await container.read(importarAvionesControllerProvider.notifier).elegirArchivo('mal.csv', _csv);
    await tester.pumpAndSettle();

    expect(find.textContaining('tiene 1 problema'), findsOneWidget);
    expect(find.text('Línea 3: Las filas deben ser un entero entre 1 y 50.'), findsOneWidget);
    await container.read(importarAvionesControllerProvider.notifier).importar(); // ni aunque se intente
    expect(api.llamadas.where((l) => l.ruta == '/aviones/importacion'), isEmpty);
  });

  testWidgets('si el servidor rechaza el archivo entero muestra su mensaje', (tester) async {
    final (_, container) = await _abrir(tester, {
      'POST /aviones/importacion/validar':
          const ServerFailure('El encabezado debe ser exactamente: matricula;modelo;filas', statusCode: 400),
    });

    await container.read(importarAvionesControllerProvider.notifier).elegirArchivo('x.csv', 'a;b\n1;2');
    await tester.pumpAndSettle();

    expect(find.textContaining('El encabezado debe ser exactamente'), findsOneWidget);
  });

  testWidgets('doble toque en Importar guarda una sola vez', (tester) async {
    final (api, container) = await _abrir(tester, {
      'POST /aviones/importacion/validar': _revision,
      'POST /aviones/importacion': (_) => Future<Object?>.delayed(
            const Duration(seconds: 1),
            () => {'mensaje': 'ok', 'creados': 1, 'omitidos': [], 'total_filas': 1},
          ),
    });
    final controlador = container.read(importarAvionesControllerProvider.notifier);
    await controlador.elegirArchivo('flota.csv', _csv);
    await tester.pumpAndSettle();

    final primero = controlador.importar();
    final segundo = controlador.importar(); // sin esperar: se ignora
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await Future.wait([primero, segundo]);

    expect(api.llamadas.where((l) => l.ruta == '/aviones/importacion'), hasLength(1));
  });
}
