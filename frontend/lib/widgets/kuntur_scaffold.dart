import 'package:flutter/material.dart';

import 'barra_kuntur.dart';
import 'navegacion_principal.dart';

/// Envoltorio único de pantalla: barra de marca, franja tricolor, navegación
/// inferior (cuando la pantalla pertenece a una sección) y un ancho máximo
/// legible en web/escritorio.
///
/// Antes cada página repetía su propio `Scaffold` + `BarraKuntur` +
/// `SafeArea` + `ConstrainedBox`; ahora todas comparten esta estructura y la
/// navegación inferior sigue siendo la misma en móvil, tablet y escritorio
/// (decisión de producto: se mantiene `NavigationBar` para no cambiar el
/// comportamiento que ya conocen los usuarios y las pruebas).
class KunturScaffold extends StatelessWidget {
  const KunturScaffold({
    super.key,
    required this.body,
    this.conAtras = false,
    this.seccion,
    this.maxAncho = 1200,
    this.onRefrescar,
    this.floatingActionButton,
    this.sinSafeArea = false,
    this.alTocarInicio,
  });

  final Widget body;
  final bool conAtras;

  /// Sección resaltada en la barra inferior; `null` oculta la navegación
  /// (pantallas de tarea: elegir asientos, comprobante, formularios).
  final Seccion? seccion;
  final double maxAncho;

  /// Si viene, la pantalla se puede refrescar arrastrando hacia abajo.
  final Future<void> Function()? onRefrescar;
  final Widget? floatingActionButton;

  /// Para pantallas que manejan su propio `SafeArea` (p. ej. mapas a sangre).
  final bool sinSafeArea;

  /// Navegación del logo de la barra (para confirmar antes de perder datos).
  final VoidCallback? alTocarInicio;

  @override
  Widget build(BuildContext context) {
    Widget contenido = body;
    if (onRefrescar != null) {
      contenido = RefreshIndicator(onRefresh: onRefrescar!, child: contenido);
    }
    contenido = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxAncho),
        // Sin barra propia: la barra de desplazamiento va en el borde de la ventana (abajo).
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: contenido,
        ),
      ),
    );
    // La barra queda pegada al borde derecho de la ventana, no al borde de la columna centrada.
    contenido = Scrollbar(child: contenido);
    // La barra usa el controlador principal de la ruta. Flutter solo conecta las listas a ese
    // controlador en Android/iOS; en web y escritorio la barra quedaba sin lista ("The Scrollbar's
    // ScrollController has no ScrollPosition attached" en cada scroll). Aquí se conectan en todas.
    final principal = PrimaryScrollController.maybeOf(context);
    if (principal != null) {
      contenido = PrimaryScrollController(
        controller: principal,
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: contenido,
      );
    }
    if (!sinSafeArea) contenido = SafeArea(child: contenido);

    return Scaffold(
      appBar: BarraKuntur(conAtras: conAtras, alTocarInicio: alTocarInicio),
      bottomNavigationBar: seccion == null ? null : NavegacionPrincipal(actual: seccion!),
      floatingActionButton: floatingActionButton,
      body: contenido,
    );
  }
}
