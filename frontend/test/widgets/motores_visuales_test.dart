import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_motion.dart';
import 'package:vuelos_app/config/app_theme.dart';
import 'package:vuelos_app/widgets/isometric_kuntur.dart';
import 'package:vuelos_app/widgets/kinetic_type.dart';
import 'package:vuelos_app/widgets/liquid_morph.dart';

Widget _marco(Widget hijo, {MediaQueryData? media}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: media ?? const MediaQueryData(),
        child: Scaffold(body: Center(child: SingleChildScrollView(child: hijo))),
      ),
    );

void main() {
  group('motores isométricos 2.5D', () {
    testWidgets('HeroIsometricoAndes se dibuja y su entrada termina', (tester) async {
      await tester.pumpWidget(_marco(const SizedBox(width: 320, child: HeroIsometricoAndes(alto: 140))));
      await tester.pumpAndSettle(); // si hubiera un bucle infinito, agotaría el tiempo
      expect(find.byType(HeroIsometricoAndes), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('proa, arco de vuelo y marco isométrico se renderizan sin errores', (tester) async {
      await tester.pumpWidget(_marco(
        const Column(
          children: [
            SizedBox(width: 260, child: ProaIsometricaAvion(alto: 52)),
            SizedBox(width: 260, child: ArcoVueloIsometrico(alto: 48)),
            SizedBox(
              width: 220,
              child: MarcoIsometrico25D(activo: true, child: Text('Tarjeta 2.5D')),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Tarjeta 2.5D'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AsientoIsometrico3D muestra el número y ocupa con X', (tester) async {
      await tester.pumpWidget(_marco(
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 44, height: 44, child: AsientoIsometrico3D(numero: '1A')),
            SizedBox(width: 44, height: 44, child: AsientoIsometrico3D(numero: '1B', ocupado: true)),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1A'), findsOneWidget);
      expect(find.text('1B'), findsNothing); // el ocupado dibuja una X
    });
  });

  group('tipografía cinética', () {
    testWidgets('TituloCinetico deja un único Text y completa la animación', (tester) async {
      await tester.pumpWidget(_marco(const TituloCinetico('Hola, Ana')));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Ana'), findsOneWidget);
    });

    testWidgets('OdometroCinetico conserva el texto exacto al cambiar el valor', (tester) async {
      await tester.pumpWidget(_marco(const OdometroCinetico(texto: r'$0.00')));
      await tester.pumpAndSettle();
      expect(find.text(r'$0.00'), findsOneWidget);

      await tester.pumpWidget(_marco(const OdometroCinetico(texto: r'$86.83')));
      await tester.pumpAndSettle();
      expect(find.text(r'$86.83'), findsOneWidget);
      expect(find.text(r'$0.00'), findsNothing);
    });

    testWidgets('TextoRutaCinetica compone origen y destino', (tester) async {
      await tester.pumpWidget(_marco(const TextoRutaCinetica(origen: 'Quito', destino: 'Guayaquil')));
      await tester.pumpAndSettle();
      expect(find.text('Quito → Guayaquil'), findsOneWidget);
    });
  });

  group('morfismo líquido', () {
    testWidgets('FondoLiquidMorph se dibuja y anima sin bucles infinitos', (tester) async {
      await tester.pumpWidget(_marco(const SizedBox(width: 320, height: 160, child: FondoLiquidMorph(fase: 0.4))));
      await tester.pumpAndSettle();
      expect(find.byType(FondoLiquidMorph), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SelectorLiquidMorph cambia la selección al tocar una opción', (tester) async {
      var seleccion = 0;
      await tester.pumpWidget(_marco(StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 320,
          child: SelectorLiquidMorph<int>(
            opciones: const [
              OpcionLiquid(valor: 0, etiqueta: 'Factura'),
              OpcionLiquid(valor: 1, etiqueta: 'Factura XML'),
            ],
            seleccion: seleccion,
            onCambio: (valor) => setState(() => seleccion = valor),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Factura XML'), findsOneWidget);

      await tester.tap(find.text('Factura XML'));
      await tester.pumpAndSettle();
      expect(seleccion, 1);
    });

    testWidgets('BarraLiquidMorph llega al valor pedido', (tester) async {
      await tester.pumpWidget(_marco(const SizedBox(width: 240, child: BarraLiquidMorph(valor: 0.75))));
      await tester.pumpAndSettle();
      final barra = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(barra.value, closeTo(0.75, 0.001));
    });

    testWidgets('ContenedorLiquidMorph expande y colapsa', (tester) async {
      await tester.pumpWidget(_marco(const ContenedorLiquidMorph(child: Text('Contenido'))));
      await tester.pumpAndSettle();
      expect(find.text('Contenido'), findsOneWidget);
    });
  });

  testWidgets('Reduce Motion deja las duraciones de los motores en cero', (tester) async {
    late Duration heroe;
    late Duration lenta;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          heroe = AppMotion.heroeDe(context);
          lenta = AppMotion.lentaDe(context);
          return const SizedBox.shrink();
        }),
      ),
    ));
    expect(heroe, Duration.zero);
    expect(lenta, Duration.zero);
  });
}
