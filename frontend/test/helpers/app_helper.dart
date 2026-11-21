import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/config/providers.dart';
import 'package:vuelos_app/pages/inicio_page.dart';
import 'package:vuelos_app/main.dart';
import 'package:vuelos_app/services/auth_service.dart';
import 'package:vuelos_app/services/avion_service.dart';
import 'package:vuelos_app/services/iva_service.dart';
import 'package:vuelos_app/services/reserva_service.dart';
import 'package:vuelos_app/services/sistema_service.dart';
import 'package:vuelos_app/services/vuelo_service.dart';

import 'fakes.dart';
import 'google_falso.dart';

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
  // Sin sesión la app abre en la página de inicio; casi todas las pruebas parten del login.
  bool desdeLogin = true,
  // Por defecto Google no está disponible (el botón no se muestra); las pruebas de Google pasan su propio doble.
  ProveedorGoogleFalso? google,
}) async {
  usarPantallaGrande(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(client, tokens ?? InMemoryTokenStorage())),
      proveedorGoogleProvider.overrideWithValue(google ?? ProveedorGoogleFalso(disponible: false)),
      avionServiceProvider.overrideWithValue(AvionService(client)),
      sistemaServiceProvider.overrideWithValue(SistemaService(client)),
      vueloServiceProvider.overrideWithValue(VueloService(client)),
      ivaServiceProvider.overrideWithValue(IvaService(client)),
      reservaServiceProvider.overrideWithValue(ReservaService(client)),
    ],
    child: const KunturApp(),
  ));
  if (esperar) await tester.pumpAndSettle();
  if (esperar && desdeLogin && find.byType(InicioPage).evaluate().isNotEmpty) {
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(appRouterProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();
  }
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

/// Abre el menú de cuenta (el avatar de la barra superior) y cierra la sesión confirmando el aviso.
Future<void> cerrarSesionDesdeElMenu(WidgetTester tester) async {
  await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sí, cerrar sesión'));
  await tester.pumpAndSettle();
}
