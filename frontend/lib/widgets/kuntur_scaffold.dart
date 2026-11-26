import 'package:flutter/material.dart';

import 'barra_kuntur.dart';
import 'navegacion_principal.dart';

/// Punto de quiebre a partir del cual las secciones principales pasan a la barra superior
/// (`BarraKuntur`) en lugar de estirar una `NavigationBar` móvil de extremo a extremo.
const double anchoNavegacionEscritorio = 1024;

/// Envoltorio único de pantalla: barra de marca, franja tricolor, navegación
/// adaptativa (pestañas en barra superior en escritorio `>= 1024 px` y `NavigationBar`
/// inferior en móvil/tablet `< 1024 px`) y ancho máximo legible.
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

  /// Sección resaltada; `null` oculta la navegación principal (tareas focalizadas).
  final Seccion? seccion;
  final double maxAncho;

  /// Si viene, la pantalla se puede refrescar arrastrando hacia abajo.
  final Future<void> Function()? onRefrescar;
  final Widget? floatingActionButton;

  /// Para pantallas que manejan su propio `SafeArea`.
  final bool sinSafeArea;

  /// Navegación del logo de la barra (para confirmar antes de perder datos).
  final VoidCallback? alTocarInicio;

  @override
  Widget build(BuildContext context) {
    final esEscritorio = MediaQuery.sizeOf(context).width >= anchoNavegacionEscritorio;

    Widget contenido = body;
    if (onRefrescar != null) {
      contenido = RefreshIndicator(onRefresh: onRefrescar!, child: contenido);
    }
    contenido = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxAncho),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: contenido,
        ),
      ),
    );
    contenido = Scrollbar(child: contenido);
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
      appBar: BarraKuntur(
        conAtras: conAtras,
        alTocarInicio: alTocarInicio,
        seccionEscritorio: esEscritorio ? seccion : null,
      ),
      bottomNavigationBar: seccion == null || esEscritorio ? null : NavegacionPrincipal(actual: seccion!),
      floatingActionButton: floatingActionButton,
      body: contenido,
    );
  }
}
