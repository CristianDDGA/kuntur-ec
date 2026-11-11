import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Filtros y página que el usuario eligió. Se guardan aparte de la lista para que al volver
/// desde el detalle la búsqueda siga como estaba.
class FiltroVuelosController extends Notifier<FiltroVuelos> {
  @override
  FiltroVuelos build() => const FiltroVuelos();

  /// Una búsqueda nueva siempre empieza en la página 1.
  void aplicar(FiltroVuelos filtro) => state = filtro.conPagina(1);

  void limpiar() => state = const FiltroVuelos();

  /// Cambia de página manteniendo los filtros. Ignora números fuera de rango.
  void irAPagina(int pagina) {
    if (pagina < 1 || pagina == state.pagina) return;
    state = state.conPagina(pagina);
  }
}

final filtroVuelosProvider =
    NotifierProvider<FiltroVuelosController, FiltroVuelos>(FiltroVuelosController.new);

/// Controlador (C) de la lista de vuelos: se vuelve a cargar cada vez que cambia el filtro o la página.
class VuelosController extends AsyncNotifier<PaginaVuelos> {
  @override
  Future<PaginaVuelos> build() async {
    final filtro = ref.watch(filtroVuelosProvider);
    try {
      return await ref.read(vueloServiceProvider).buscar(filtro);
    } on UnauthorizedFailure {
      await ref.read(sesionControllerProvider.notifier).sesionExpirada();
      rethrow;
    }
  }

  /// Botón "Reintentar" y "actualizar".
  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }
}

final vuelosControllerProvider = AsyncNotifierProvider<VuelosController, PaginaVuelos>(
  VuelosController.new,
  retry: (_, _) => null,
);
