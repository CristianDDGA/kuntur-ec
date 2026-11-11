import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/providers.dart';
import 'package:vuelos_app/main.dart';
import 'package:vuelos_app/services/auth_service.dart';
import 'package:vuelos_app/services/iva_service.dart';
import 'package:vuelos_app/services/sistema_service.dart';
import 'package:vuelos_app/services/vuelo_service.dart';

import 'fakes.dart';

/// Pantalla grande para que los formularios completos se vean sin hacer scroll.
void usarPantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Abre la app completa (router incluido) con la API y el token simulados.
Future<void> abrirApp(
  WidgetTester tester, {
  required RouteFakeRestClient client,
  InMemoryTokenStorage? tokens,
  bool esperar = true,
}) async {
  usarPantallaGrande(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(client, tokens ?? InMemoryTokenStorage())),
      sistemaServiceProvider.overrideWithValue(SistemaService(client)),
      vueloServiceProvider.overrideWithValue(VueloService(client)),
      ivaServiceProvider.overrideWithValue(IvaService(client)),
    ],
    child: const KunturApp(),
  ));
  if (esperar) await tester.pumpAndSettle();
}

/// Campo de texto por su etiqueta visible.
Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

Future<void> escribir(WidgetTester tester, String etiqueta, String texto) async {
  await tester.enterText(campo(etiqueta), texto);
  await tester.pump();
}

Future<void> tocarBoton(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pump();
}
