import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_router.dart';
import 'package:vuelos_app/pages/admin_page.dart';
import 'package:vuelos_app/pages/comprobante_page.dart';
import 'package:vuelos_app/pages/crear_vuelo_page.dart';
import 'package:vuelos_app/pages/inicio_page.dart';
import 'package:vuelos_app/pages/login_page.dart';
import 'package:vuelos_app/pages/reserva_detalle_page.dart';
import 'package:vuelos_app/pages/reservas_page.dart';
import 'package:vuelos_app/pages/seleccion_asientos_page.dart';
import 'package:vuelos_app/pages/vuelo_detalle_page.dart';
import 'package:vuelos_app/pages/vuelos_page.dart';
import 'package:vuelos_app/widgets/isometric_kuntur.dart';
import 'package:vuelos_app/widgets/logo_kuntur.dart';

import '../helpers/app_helper.dart';
import '../helpers/fakes.dart';
import '../helpers/google_falso.dart';

void _tamano(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

RouteFakeRestClient _clienteCompleto({Object usuario = usuarioAna}) => RouteFakeRestClient({
      'GET /auth/perfil': {'usuario': usuario},
      'POST /auth/logout': {'mensaje': 'ok'},
      'GET /health': healthOk,
      'GET /vuelos': respuestaVuelos,
      'GET /vuelos/destinos': {
        'destinos': [
          {'ciudad': 'Quito', 'precio_minimo': 75, 'vuelos': 2},
          {'ciudad': 'Guayaquil', 'precio_minimo': 80, 'vuelos': 3},
        ],
      },
      'GET /vuelos/3': {...vueloQuitoGuayaquil, 'precio': '11500.00'},
      'GET /vuelos/3/asientos': mapaJson(capacidad: 16, ocupados: ['1B']),
      'GET /iva': respuestaIva,
      'GET /aviones': listaAviones,
      'GET /reservas': {
        ...paginaDeReservas(total: 1, pagina: 1),
        'reservas': [reservaJson(total: '11500.00')],
      },
      'GET /reservas/58': reservaJson(total: '11500.00'),
      'GET /reservas/58/comprobante': facturaXml(total: '11500.00'),
      'GET /reservas/resumen': {
        'total': '22400.00',
        'iva': '2921.74',
        'confirmadas': 12,
        'canceladas': 1,
        'asientos_vendidos': 30,
        'top': [
          {'codigo': 'KT101', 'ruta': 'Quito → Guayaquil', 'asientos': 18, 'total': '15000.00'},
        ],
      },
    });

void main() {
  group('login compacto, simétrico y sin scroll', () {
    testWidgets('reemplaza la imagen por solo el logo centrado y entra sin scroll en laptop y móvil', (tester) async {
      await abrirApp(
        tester,
        client: _clienteCompleto(),
        google: ProveedorGoogleFalso(disponible: true),
      );

      for (final tamano in [const Size(1280, 720), const Size(375, 667), const Size(1440, 900)]) {
        _tamano(tester, tamano);
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(HeroIsometricoAndes), findsNothing);
        expect(find.byType(MarcaKuntur), findsOneWidget);

        // El logo y la tarjeta quedan centrados en el mismo eje vertical.
        final centroLogo = tester.getCenter(find.byType(MarcaKuntur)).dx;
        final centroTarjeta = tester.getCenter(find.byType(MarcoIsometrico25D)).dx;
        expect((centroLogo - centroTarjeta).abs(), lessThanOrEqualTo(1.0), reason: 'Asimetría en $tamano');

        // Sin scroll innecesario en resoluciones estándar (laptop 720p y móvil).
        final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable)).toList();
        expect(scrollables, isNotEmpty);
        final estadoScroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
        expect(estadoScroll.position.maxScrollExtent, equals(0.0), reason: 'Apareció scroll en $tamano');
        expect(tester.takeException(), isNull, reason: 'Error de layout en $tamano');
      }
    });

    testWidgets('al minimizar a ventana muy pequeña hace scroll sin desbordar', (tester) async {
      await abrirApp(tester, client: _clienteCompleto());
      _tamano(tester, const Size(320, 460));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });

  group('adaptabilidad responsive al minimizar y maximizar todo el frontend', () {
    const tamanos = [
      Size(340, 640), // móvil / ventana minimizada estrecha
      Size(500, 720), // ventana mediana / media pantalla
      Size(1440, 900), // escritorio maximizado
    ];

    testWidgets('InicioPage (landing pública) se adapta de 340 px a 1440 px sin desbordar', (tester) async {
      await abrirApp(tester, client: _clienteCompleto(), desdeLogin: false);

      for (final tamano in tamanos) {
        _tamano(tester, tamano);
        await tester.pumpAndSettle();

        expect(find.byType(InicioPage), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Overflow en InicioPage con $tamano');
      }
    });

    testWidgets('flujo cliente completo soporta cambios continuos de tamaño sin distorsión ni pérdida de flujo',
        (tester) async {
      await abrirApp(tester, client: _clienteCompleto(), tokens: InMemoryTokenStorage('jwt'));
      final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider);

      Future<void> verificarRuta(String ruta, Type pagina, {Future<void> Function()? extra}) async {
        router.go(ruta);
        await tester.pumpAndSettle();
        expect(find.byType(pagina), findsOneWidget);
        for (final tamano in tamanos) {
          _tamano(tester, tamano);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Overflow en $pagina con $tamano');
        }
        if (extra != null) await extra();
      }

      await verificarRuta(AppRoutes.vuelos, VuelosPage);
      await verificarRuta(AppRoutes.vuelo(3), VueloDetallePage);
      await verificarRuta(AppRoutes.asientosDelVuelo(3), SeleccionAsientosPage);
      await verificarRuta(AppRoutes.reservas, ReservasPage);
      await verificarRuta(AppRoutes.reserva(58), ReservaDetallePage);
      await verificarRuta(
        AppRoutes.comprobante(58),
        ComprobantePage,
        extra: () async {
          await tester.tap(find.text('Factura XML'));
          await tester.pumpAndSettle();
          for (final tamano in tamanos) {
            _tamano(tester, tamano);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Overflow en Comprobante XML con $tamano');
          }
        },
      );
    });

    testWidgets('flujo administrador (AdminPage y CrearVueloPage) soporta cambios de tamaño sin desbordar',
        (tester) async {
      await abrirApp(tester, client: _clienteCompleto(usuario: usuarioAdmin), tokens: InMemoryTokenStorage('jwt'));
      final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider);

      for (final ruta in <(String, Type)>[
        (AppRoutes.vuelos, VuelosPage),
        (AppRoutes.admin, AdminPage),
        (AppRoutes.nuevoVuelo, CrearVueloPage),
      ]) {
        router.go(ruta.$1);
        await tester.pumpAndSettle();
        expect(find.byType(ruta.$2), findsOneWidget);
        for (final tamano in tamanos) {
          _tamano(tester, tamano);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Overflow en ${ruta.$2} con $tamano');
        }
      }
    });

    testWidgets('pantallas de registro, importación CSV, estado SOA y ruta no encontrada se adaptan sin desbordar',
        (tester) async {
      await abrirApp(tester, client: _clienteCompleto(usuario: usuarioAdmin), tokens: InMemoryTokenStorage('jwt'));
      final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(appRouterProvider);

      for (final ruta in [AppRoutes.importarAviones, AppRoutes.estado, '/ruta-inexistente-xyz']) {
        router.go(ruta);
        await tester.pumpAndSettle();
        for (final tamano in tamanos) {
          _tamano(tester, tamano);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Overflow en $ruta con $tamano');
        }
      }

      // Cerrar sesión para recorrer RegistroPage en todos los tamaños.
      await cerrarSesionDesdeElMenu(tester);
      router.go(AppRoutes.registro);
      await tester.pumpAndSettle();
      for (final tamano in tamanos) {
        _tamano(tester, tamano);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow en RegistroPage con $tamano');
      }
    });
  });
}
