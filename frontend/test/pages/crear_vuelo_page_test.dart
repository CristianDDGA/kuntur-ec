import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/crear_vuelo_page.dart';
import 'package:vuelos_app/widgets/campo_selector.dart';
import 'package:vuelos_app/pages/vuelo_detalle_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';

/// Abre la app como administrador y entra al formulario.
Future<RouteFakeRestClient> _abrirFormulario(WidgetTester tester, Map<String, Object?> rutas,
    {Object usuario = usuarioAdmin}) async {
  final client = RouteFakeRestClient({
    'GET /auth/perfil': {'usuario': usuario},
    'GET /vuelos': sinVuelos,
    ...rutas,
  });
  await abrirApp(tester, client: client, tokens: InMemoryTokenStorage('jwt'));
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider).push(AppRoutes.nuevoVuelo);
  await tester.pumpAndSettle();
  return client;
}

/// El campo selector por su etiqueta (se toca el campo entero, no solo el texto de la etiqueta).
Finder _selector<T>(String etiqueta) =>
    find.byWidgetPredicate((w) => w is CampoSelector<T> && w.etiqueta == etiqueta);

/// Elige una fecha en el selector de Material (la abre, toca el día y confirma).
Future<void> _elegirFecha(WidgetTester tester, String etiqueta) async {
  await tester.tap(_selector<DateTime>(etiqueta));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _elegirHora(WidgetTester tester, String etiqueta) async {
  await tester.tap(_selector<Duration>(etiqueta));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un cliente no puede abrir el formulario: vuelve a la lista', (tester) async {
    await _abrirFormulario(tester, {}, usuario: usuarioAna);
    expect(find.byType(CrearVueloPage), findsNothing);
    expect(find.byType(VuelosPage), findsOneWidget);
  });

  testWidgets('campos vacíos: muestra todos los errores y no llama a la API', (tester) async {
    final api = await _abrirFormulario(tester, {});

    await tester.ensureVisible(find.text('Crear vuelo'));
    await tocarBoton(tester, 'Crear vuelo');
    await tester.pumpAndSettle();

    expect(find.text('El origen es obligatorio.'), findsOneWidget);
    expect(find.text('El destino es obligatorio.'), findsOneWidget);
    expect(find.text('Elija la fecha del vuelo.'), findsOneWidget);
    expect(find.text('La hora de salida es obligatoria.'), findsOneWidget);
    expect(find.text('El precio es obligatorio.'), findsOneWidget);
    expect(find.text('La capacidad es obligatoria.'), findsOneWidget);
    expect(api.llamadas.where((l) => l.metodo == 'POST'), isEmpty);
  });

  testWidgets('escribir en un campo no marca errores en los demás', (tester) async {
    await _abrirFormulario(tester, {});

    await escribir(tester, 'Origen', 'Quito');

    expect(find.text('El destino es obligatorio.'), findsNothing);
    expect(find.text('Elija la fecha del vuelo.'), findsNothing);
    expect(find.text('El precio es obligatorio.'), findsNothing);
  });

  testWidgets('destino igual al origen se rechaza antes de enviar', (tester) async {
    await _abrirFormulario(tester, {});

    await escribir(tester, 'Origen', 'Quito');
    await escribir(tester, 'Destino', 'quito');

    expect(find.text('Debe ser distinto del origen.'), findsOneWidget);
  });

  testWidgets('no pide código y bloquea emojis, números y largo excesivo al escribir', (tester) async {
    await _abrirFormulario(tester, {});

    expect(find.text('Código del vuelo'), findsNothing);
    await tester.enterText(campo('Origen'), 'Qu1to 😀 <b>${'a' * 100}');
    await tester.pump();

    final texto = tester.widget<TextFormField>(campo('Origen')).controller!.text;
    expect(texto.length, 80);
    expect(texto, isNot(contains('😀')));
    expect(RegExp(r'[0-9<>]').hasMatch(texto), isFalse);
    expect(find.text('No puede superar 80 caracteres.'), findsNothing);
  });

  testWidgets('precio y capacidad: no pasan de sus límites y siempre se pueden borrar o limpiar', (tester) async {
    await _abrirFormulario(tester, {});
    final precio = tester.widget<TextFormField>(campo('Precio por persona (USD)')).controller!;
    final capacidad = tester.widget<TextFormField>(campo('Capacidad (asientos)')).controller!;

    await tester.enterText(campo('Capacidad (asientos)'), '90');
    await tester.enterText(campo('Capacidad (asientos)'), '201'); // pasaría de 200: se ignora
    await tester.pump();
    expect(capacidad.text, '90');
    await tester.enterText(campo('Capacidad (asientos)'), '9'); // borrar un dígito
    await tester.enterText(campo('Capacidad (asientos)'), ''); // y vaciar
    await tester.pump();
    expect(capacidad.text, isEmpty);

    await tester.enterText(campo('Precio por persona (USD)'), '75.5');
    await tester.pump();
    expect(find.byTooltip('Borrar'), findsOneWidget); // aparece el botón X cuando hay texto
    await tester.tap(find.byTooltip('Borrar'));
    await tester.pump();
    expect(precio.text, isEmpty);
    expect(find.byTooltip('Borrar'), findsNothing);
  });

  testWidgets('hoy, la hora sugerida es una posterior a la actual y no da error', (tester) async {
    await _abrirFormulario(tester, {});
    final ahora = DateTime.now();
    if (ahora.hour == 23 && ahora.minute == 59) return; // a esa hora no existe una salida válida hoy
    await _elegirFecha(tester, 'Fecha'); // el selector propone hoy
    await _elegirHora(tester, 'Hora de salida'); // y la hora propuesta es la siguiente hora completa

    expect(find.textContaining('ya pasó'), findsNothing);
  });

  testWidgets('crea el vuelo: envía el cuerpo normalizado y abre su detalle', (tester) async {
    final api = await _abrirFormulario(tester, {
      'POST /vuelos': {'mensaje': 'Vuelo creado correctamente.', 'vuelo': vueloQuitoGuayaquil},
      'GET /vuelos/3': vueloQuitoGuayaquil,
    });

    await escribir(tester, 'Origen', '  Quito ');
    await escribir(tester, 'Destino', 'Guayaquil');
    await escribir(tester, 'Precio por persona (USD)', '75,5');
    await escribir(tester, 'Capacidad (asientos)', '80');
    await _elegirFecha(tester, 'Fecha');
    await _elegirHora(tester, 'Hora de salida');
    await _elegirHora(tester, 'Hora de llegada');

    await tester.ensureVisible(find.text('Crear vuelo'));
    await tocarBoton(tester, 'Crear vuelo');
    await tester.pumpAndSettle();

    final cuerpo = api.llamada('POST', '/vuelos').cuerpo as Map;
    expect(cuerpo.containsKey('codigo'), isFalse); // el código lo genera el servidor
    expect(cuerpo['origen'], 'Quito');
    expect(cuerpo['precio'], '75.5');
    expect(cuerpo['capacidad'], 80);
    expect(cuerpo['hora_salida'], matches(RegExp(r'^\d{2}:\d{2}$')));
    expect(find.byType(VueloDetallePage), findsOneWidget);
  });

  testWidgets('doble toque rápido en "Crear vuelo" envía una sola petición', (tester) async {
    final api = await _abrirFormulario(tester, {
      'POST /vuelos': (_) => Future<Object?>.delayed(
            const Duration(seconds: 1),
            () => {'mensaje': 'ok', 'vuelo': vueloQuitoGuayaquil},
          ),
      'GET /vuelos/3': vueloQuitoGuayaquil,
    });

    await escribir(tester, 'Origen', 'Quito');
    await escribir(tester, 'Destino', 'Guayaquil');
    await escribir(tester, 'Precio por persona (USD)', '75.50');
    await escribir(tester, 'Capacidad (asientos)', '80');
    await _elegirFecha(tester, 'Fecha');
    await _elegirHora(tester, 'Hora de salida');
    await _elegirHora(tester, 'Hora de llegada');
    await tester.ensureVisible(find.text('Crear vuelo'));

    await tester.tap(find.text('Crear vuelo'));
    await tester.tap(find.text('Crear vuelo')); // sin esperar ningún frame entre toque y toque
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(api.llamadas.where((l) => l.metodo == 'POST'), hasLength(1));
  });

  testWidgets('error del servidor (409): muestra el mensaje y se queda en el formulario', (tester) async {
    await _abrirFormulario(tester, {
      'POST /vuelos': const ServerFailure('No se pudo asignar un código de vuelo. Intente nuevamente.', statusCode: 409),
    });

    await escribir(tester, 'Origen', 'Quito');
    await escribir(tester, 'Destino', 'Guayaquil');
    await escribir(tester, 'Precio por persona (USD)', '75.50');
    await escribir(tester, 'Capacidad (asientos)', '80');
    await _elegirFecha(tester, 'Fecha');
    await _elegirHora(tester, 'Hora de salida');
    await _elegirHora(tester, 'Hora de llegada');
    await tester.ensureVisible(find.text('Crear vuelo'));
    await tocarBoton(tester, 'Crear vuelo');
    await tester.pumpAndSettle();

    expect(find.text('No se pudo asignar un código de vuelo. Intente nuevamente.'), findsOneWidget);
    expect(find.byType(CrearVueloPage), findsOneWidget);
  });
}
