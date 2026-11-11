import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/reserva.dart';
import 'con_sesion.dart';

/// Página del historial que el usuario está viendo (se conserva al entrar y salir de un detalle).
class PaginaReservasController extends Notifier<int> {
  @override
  int build() => 1;

  void irA(int pagina) {
    if (pagina >= 1 && pagina != state) state = pagina;
  }

  void primera() => state = 1;
}

final paginaReservasProvider = NotifierProvider<PaginaReservasController, int>(PaginaReservasController.new);

/// Controlador (C) de "Mis reservas".
class ReservasController extends AsyncNotifier<PaginaReservas> {
  @override
  Future<PaginaReservas> build() {
    final pagina = ref.watch(paginaReservasProvider);
    return conSesion(ref, () => ref.read(reservaServiceProvider).listar(pagina: pagina));
  }

  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }
}

final reservasControllerProvider = AsyncNotifierProvider.autoDispose<ReservasController, PaginaReservas>(
  ReservasController.new,
  retry: (_, _) => null,
);
