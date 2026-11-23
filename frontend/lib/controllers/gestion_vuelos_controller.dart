import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/vuelo.dart';
import 'con_sesion.dart';
import 'resumen_ventas_controller.dart';
import 'vuelo_detalle_controller.dart';
import 'vuelos_controller.dart';

/// Filtro y página del listado de gestión (se conservan al entrar a editar y volver).
class FiltroGestionController extends Notifier<FiltroGestion> {
  @override
  FiltroGestion build() => const FiltroGestion();

  /// Cambiar el estado vuelve a la primera página.
  void estado(EstadoVuelo? estado) {
    if (estado != state.estado) state = FiltroGestion(estado: estado);
  }

  void irA(int pagina) {
    if (pagina >= 1 && pagina != state.pagina) state = FiltroGestion(estado: state.estado, pagina: pagina);
  }
}

final filtroGestionProvider = NotifierProvider<FiltroGestionController, FiltroGestion>(FiltroGestionController.new);

/// Controlador (C) del listado de vuelos del administrador.
class GestionVuelosController extends AsyncNotifier<PaginaGestion> {
  @override
  Future<PaginaGestion> build() {
    final filtro = ref.watch(filtroGestionProvider);
    return conSesion(ref, () => ref.read(vueloServiceProvider).gestion(filtro));
  }

  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }
}

final gestionVuelosProvider = AsyncNotifierProvider.autoDispose<GestionVuelosController, PaginaGestion>(
  GestionVuelosController.new,
  retry: (_, _) => null,
);

/// Lo que cambia al editar o cancelar un vuelo: el listado de gestión, la búsqueda pública,
/// el detalle del vuelo y el resumen de ventas (cancelar devuelve reservas).
void _refrescarVistas(Ref ref, int vueloId) {
  ref.invalidate(gestionVuelosProvider);
  ref.invalidate(vuelosControllerProvider);
  ref.invalidate(vueloDetalleControllerProvider(vueloId));
  ref.invalidate(resumenVentasProvider);
}

/// Controlador (C) de "Editar vuelo". `AsyncData(vuelo)` = guardado; `AsyncError` = rechazado.
class EditarVueloController extends AsyncNotifier<Vuelo?> {
  @override
  FutureOr<Vuelo?> build() => null;

  /// Devuelve el vuelo guardado, o `null` si falló (el error queda en el estado).
  Future<Vuelo?> editar(int id, EdicionVuelo datos) async {
    if (state.isLoading) return null; // doble toque: no se envía dos veces
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(
      () => conSesion(ref, () => ref.read(vueloServiceProvider).editar(id, datos)),
    );
    if (!ref.mounted) return resultado.value;
    state = resultado;
    if (resultado.hasValue) _refrescarVistas(ref, id);
    return resultado.value;
  }
}

final editarVueloControllerProvider = AsyncNotifierProvider.autoDispose<EditarVueloController, Vuelo?>(
  EditarVueloController.new,
  retry: (_, _) => null,
);

/// Cancela un vuelo (C). Devuelve cuántas reservas se cancelaron con él; si falla lanza el error
/// para que la pantalla lo muestre en el mismo diálogo.
class CancelarVueloController extends Notifier<bool> {
  @override
  bool build() => false; // `true` mientras hay una cancelación en curso

  Future<int?> cancelar(Vuelo vuelo, String motivo) async {
    if (state) return null;
    state = true;
    try {
      final r = await conSesion(
        ref,
        () => ref.read(vueloServiceProvider).cancelar(vuelo.id, motivo: motivo, version: vuelo.version),
      );
      _refrescarVistas(ref, vuelo.id);
      return r.reservasCanceladas;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final cancelarVueloProvider = NotifierProvider.autoDispose<CancelarVueloController, bool>(CancelarVueloController.new);
