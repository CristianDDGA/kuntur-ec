import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/config/app_motion.dart';
import 'package:vuelos_app/config/app_theme.dart';
import 'package:vuelos_app/widgets/asiento_boton.dart';
import 'package:vuelos_app/widgets/estado_vista.dart';
import 'package:vuelos_app/widgets/hoja_confirmacion.dart';
import 'package:vuelos_app/widgets/skeleton_kuntur.dart';

/// Widget simple para abrir la confirmación desde un toque.
class _AbrirConfirmacion extends StatelessWidget {
  const _AbrirConfirmacion({required this.onResultado});

  final ValueChanged<bool> onResultado;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final confirmado = await mostrarConfirmacionKuntur(
                context,
                titulo: '¿Eliminar la reserva?',
                mensaje: 'Esta acción no se puede deshacer.',
                textoConfirmar: 'Eliminar',
                textoCancelar: 'Conservar',
                estilo: EstiloConfirmacion.destructiva,
              );
              onResultado(confirmado);
            },
            child: const Text('abrir'),
          ),
        ),
      );
}

void main() {
  testWidgets('el asiento ofrece un área táctil de al menos 44 pt y su etiqueta', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: AsientoBoton(numero: '1A', estado: EstadoAsiento.libre, onTap: () {}),
        ),
      ),
    ));

    final area = tester.getSize(find.byType(InkWell));
    expect(area.width, greaterThanOrEqualTo(44));
    expect(area.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Asiento 1A, disponible'), findsOneWidget);
    // El nodo semántico debe exponer la acción de toque (VoiceOver/TalkBack).
    expect(tester.getSemantics(find.byType(AsientoBoton)).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('Reduce Motion deja las duraciones en cero', (tester) async {
    late Duration media;
    late Duration rapida;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          media = AppMotion.mediaDe(context);
          rapida = AppMotion.rapidaDe(context);
          return const SizedBox.shrink();
        }),
      ),
    ));
    expect(media, Duration.zero);
    expect(rapida, Duration.zero);
  });

  testWidgets('la confirmación destructiva deja la acción segura como primaria', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? resultado;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: _AbrirConfirmacion(onResultado: (valor) => resultado = valor),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar la reserva?'), findsOneWidget);
    // La salida segura ("Conservar") es el botón relleno; "Eliminar" queda como acción de texto.
    expect(find.widgetWithText(FilledButton, 'Conservar'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Eliminar'), findsOneWidget);

    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);
  });

  testWidgets('el esqueleto de carga termina sus animaciones', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: SkeletonListaTarjetas(cantidad: 2))),
    ));
    // Si el esqueleto dejara un bucle infinito, pumpAndSettle agotaría el tiempo.
    await tester.pumpAndSettle();
    expect(find.byType(Esqueleto), findsWidgets);
  });

  testWidgets('el estado vacío muestra título, mensaje y acción reutilizable', (tester) async {
    var tocado = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: VacioVista(
          icono: Icons.flight_takeoff,
          titulo: 'No hay vuelos programados.',
          mensaje: 'Vuelva a consultar más tarde.',
          textoAccion: 'Reintentar',
          onAccion: () => tocado = true,
        ),
      ),
    ));

    expect(find.text('No hay vuelos programados.'), findsOneWidget);
    expect(find.text('Vuelva a consultar más tarde.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(tocado, isTrue);
  });
}
