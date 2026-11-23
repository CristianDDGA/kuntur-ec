import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/crear_vuelo_page.dart';
import 'package:vuelos_app/pages/gestion_vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/widgets/campo_texto_kuntur.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

const _cancelado = {
  ...vueloCuencaQuito,
  'estado': 'cancelado',
  'motivo_cancelacion': 'Cierre del aeropuerto por ceniza',
  'ya_partio': false,
};

Map<String, Object?> _pagina() => {
      'total': 2,
      'pagina': 1,
      'por_pagina': 10,
      'total_paginas': 1,
      'vuelos': [
        {...vueloQuitoGuayaquil, 'ya_partio': false, 'avion_id': 7},
        _cancelado,
      ],
    };

Future<RouteFakeRestClient> _abrirGestion(WidgetTester tester, Map<String, Object?> rutas,
    {Object usuario = usuarioAdmin}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': sinVuelos,
    'GET /vuelos/gestion': _pagina(),
    'GET /aviones': listaAviones,
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(AppRoutes.gestionVuelos);
  await tester.pumpAndSettle();
  return client;
}

/// El campo de texto del formulario por su etiqueta.
CampoTextoKuntur _campoKuntur(WidgetTester tester, String etiqueta) =>
    tester.widget<CampoTextoKuntur>(find.byWidgetPredicate((w) => w is CampoTextoKuntur && w.etiqueta == etiqueta));

void main() {
  testWidgets('lista los vuelos con su estado; uno cancelado muestra el motivo y no tiene acciones', (tester) async {
    await _abrirGestion(tester, {});

    expect(find.byType(GestionVuelosPage), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('38 de 80 asientos vendidos'), findsOneWidget);
    expect(find.text('Motivo: Cierre del aeropuerto por ceniza'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget); // solo el vuelo programado
    expect(find.text('Cancelar vuelo'), findsOneWidget);
  });

  testWidgets('el filtro "Cancelados" pide solo esos vuelos', (tester) async {
    final client = await _abrirGestion(tester, {});
    await tester.tap(find.text('Cancelados'));
    await tester.pumpAndSettle();
    expect(client.llamadas.last.consulta?['estado'], 'cancelado');
  });

  testWidgets('cancelar exige un motivo claro y luego envía motivo y versión', (tester) async {
    final client = await _abrirGestion(tester, {
      'POST /vuelos/3/cancelacion': {
        'mensaje': 'Vuelo cancelado correctamente.',
        'vuelo': {...vueloQuitoGuayaquil, 'estado': 'cancelado', 'motivo_cancelacion': 'Cierre del aeropuerto por ceniza'},
        'reservas_canceladas': 5,
      },
    });
    await tester.tap(find.text('Cancelar vuelo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar el vuelo KT101?'), findsOneWidget);
    expect(find.textContaining('38 asiento(s) vendido(s)'), findsOneWidget);

    // Sin motivo no se envía nada.
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar vuelo'));
    await tester.pumpAndSettle();
    expect(find.text('Escriba el motivo de la cancelación.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Clima');
    await tester.pumpAndSettle();
    expect(find.text('Explique el motivo con al menos 10 letras.'), findsOneWidget);
    expect(client.rutasSolicitadas.where((r) => r.contains('cancelacion')), isEmpty);

    await tester.enterText(find.byType(TextFormField).last, '  Cierre del aeropuerto   por ceniza ');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar vuelo'));
    await tester.pumpAndSettle();

    expect(client.llamada('POST', '/vuelos/3/cancelacion').cuerpo, {
      'motivo': 'Cierre del aeropuerto por ceniza',
      'version': 1,
    });
    expect(find.text('Vuelo KT101 cancelado junto con 5 reserva(s).'), findsOneWidget);
  });

  testWidgets('si el servidor rechaza la cancelación, el error se muestra en el mismo diálogo', (tester) async {
    await _abrirGestion(tester, {
      'POST /vuelos/3/cancelacion': const ServerFailure(
        'Ya actualizaron este vuelo. Consúltelo de nuevo y vuelva a intentarlo.',
        statusCode: 409,
      ),
    });
    await tester.tap(find.text('Cancelar vuelo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Cierre del aeropuerto por ceniza');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar vuelo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya actualizaron este vuelo'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget); // no se cierra: el administrador decide
  });

  testWidgets('editar un vuelo con asientos vendidos bloquea la ruta y guarda el precio con la versión', (tester) async {
    final client = await _abrirGestion(tester, {
      'GET /vuelos/3': {...vueloQuitoGuayaquil, 'avion_id': 7},
      'PUT /vuelos/3': {
        'mensaje': 'Vuelo actualizado correctamente.',
        'vuelo': {...vueloQuitoGuayaquil, 'precio': '80.00', 'version': 2, 'avion_id': 7},
      },
    });
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.byType(CrearVueloPage), findsOneWidget);
    expect(find.text('Editar vuelo KT101'), findsOneWidget);
    expect(find.textContaining('38 asiento(s) vendido(s)'), findsOneWidget);
    expect(_campoKuntur(tester, 'Origen').enabled, isFalse);
    expect(_campoKuntur(tester, 'Destino').enabled, isFalse);
    expect(_campoKuntur(tester, 'Origen').controlador.text, 'Quito');
    expect(_campoKuntur(tester, 'Precio por persona (USD)').controlador.text, '75.50');

    await tester.enterText(find.widgetWithText(TextFormField, 'Precio por persona (USD)'), '80.00');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final cuerpo = client.llamada('PUT', '/vuelos/3').cuerpo as Map;
    expect(cuerpo['precio'], '80.00');
    expect(cuerpo['version'], 1);
    expect(cuerpo['origen'], 'Quito');
    expect(cuerpo.containsKey('avion_id'), isFalse);
    expect(find.byType(GestionVuelosPage), findsOneWidget); // vuelve al listado
    expect(find.text('Vuelo KT101 actualizado correctamente.'), findsOneWidget);
  });

  testWidgets('con asientos vendidos se guarda aunque el avión no esté en la lista (no se puede cambiar)',
      (tester) async {
    final client = await _abrirGestion(tester, {
      'GET /vuelos/3': {...vueloQuitoGuayaquil, 'avion_id': 99},
      'PUT /vuelos/3': {
        'mensaje': 'Vuelo actualizado correctamente.',
        'vuelo': {...vueloQuitoGuayaquil, 'precio': '79.00', 'version': 2, 'avion_id': 99},
      },
    });
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Precio por persona (USD)'), '79');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect((client.llamada('PUT', '/vuelos/3').cuerpo as Map).containsKey('avion_id'), isFalse);
  });

  testWidgets('guardar sin cambios no llama al servidor', (tester) async {
    final client = await _abrirGestion(tester, {'GET /vuelos/3': {...vueloQuitoGuayaquil, 'avion_id': 7}});
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(client.rutasSolicitadas.where((r) => r.startsWith('PUT')), isEmpty);
    expect(find.text('No hay cambios que guardar.'), findsOneWidget);
  });

  testWidgets('un 409 al editar ofrece recargar el vuelo', (tester) async {
    await _abrirGestion(tester, {
      'GET /vuelos/3': {...vueloQuitoGuayaquil, 'avion_id': 7},
      'PUT /vuelos/3': const ServerFailure(
        'Ya actualizaron este vuelo. Consúltelo de nuevo y vuelva a intentarlo.',
        statusCode: 409,
        detalles: {'version_actual': 2},
      ),
    });
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Precio por persona (USD)'), '81');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya actualizaron este vuelo'), findsOneWidget);
    expect(find.text('Recargar el vuelo'), findsOneWidget);
  });

  testWidgets('un vuelo cancelado abierto por enlace no muestra el formulario', (tester) async {
    await _abrirGestion(tester, {'GET /vuelos/4': _cancelado});
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(AppRoutes.editarVuelo(4));
    await tester.pumpAndSettle();

    expect(find.textContaining('Este vuelo fue cancelado'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
  });

  testWidgets('un cliente no puede entrar a la gestión de vuelos', (tester) async {
    await _abrirGestion(tester, {}, usuario: usuarioAna);
    expect(find.byType(GestionVuelosPage), findsNothing);
  });
}
