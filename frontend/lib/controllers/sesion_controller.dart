import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/expiracion_token.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';

/// Mensaje que el login muestra cuando la sesión terminó sin que el usuario la cerrara
/// (el token venció o el servidor lo rechazó). Se borra al mostrarlo o al iniciar sesión.
class AvisoLoginController extends Notifier<String?> {
  @override
  String? build() => null;

  void mostrar(String mensaje) => state = mensaje;
  void limpiar() => state = null;
}

final avisoLoginProvider = NotifierProvider<AvisoLoginController, String?>(AvisoLoginController.new);

const mensajeSesionVencida = 'Su sesión venció por seguridad. Inicie sesión nuevamente para continuar.';

/// Controlador (C) de la sesión: quién está autenticado.
///
/// El estado es el [Usuario] actual o `null` si no hay sesión. El router lo observa
/// para decidir a qué pantallas se puede entrar.
///
/// Si el token vence mientras la app está abierta, la sesión se cierra sola y se lleva al login
/// explicando el motivo (no hace falta esperar a que una petición falle).
class SesionController extends AsyncNotifier<Usuario?> {
  Timer? _vencimiento;

  /// Al arrancar la app: si hay un token guardado se valida con el servidor
  /// (`GET /auth/perfil`) y así una sesión vencida o revocada no deja pasar a nadie.
  @override
  Future<Usuario?> build() async {
    ref.onDispose(() => _vencimiento?.cancel());
    final auth = ref.read(authServiceProvider);
    if (!await auth.tieneToken()) return null;
    try {
      final usuario = await auth.perfil();
      await _programarVencimiento();
      return usuario;
    } on UnauthorizedFailure {
      await auth.descartarToken();
      return null;
    }
    // Cualquier otro fallo (sin conexión, servidor caído) se propaga: la pantalla de carga
    // ofrece reintentar y el token se conserva para no cerrar la sesión por un corte de red.
  }

  /// Lo llaman el login y el registro cuando ya tienen un usuario autenticado.
  void abrir(Usuario usuario) {
    ref.read(avisoLoginProvider.notifier).limpiar();
    state = AsyncData(usuario);
    _programarVencimiento();
  }

  Future<void> cerrarSesion() async {
    _vencimiento?.cancel();
    await ref.read(authServiceProvider).cerrarSesion();
    state = const AsyncData(null);
  }

  /// Una petición devolvió 401 o el token venció: la sesión ya no es válida.
  Future<void> sesionExpirada() async {
    _vencimiento?.cancel();
    await ref.read(authServiceProvider).descartarToken();
    if (state.value != null) ref.read(avisoLoginProvider.notifier).mostrar(mensajeSesionVencida);
    state = const AsyncData(null);
  }

  /// Desde la pantalla de carga cuando el servidor no responde: seguir hacia el login.
  void continuarSinSesion() => state = const AsyncData(null);

  /// Programa el cierre automático para el momento en que vence el token guardado.
  Future<void> _programarVencimiento() async {
    _vencimiento?.cancel();
    final token = await ref.read(authServiceProvider).tokenGuardado();
    final vence = token == null ? null : ExpiracionToken.de(token);
    if (vence == null) return;
    final falta = vence.difference(DateTime.now().toUtc());
    // Si el reloj del equipo está muy desfasado, igual se cierra como máximo cuando el servidor responda 401.
    _vencimiento = Timer(falta.isNegative ? Duration.zero : falta, () {
      if (state.value != null) sesionExpirada();
    });
  }
}

/// `retry: null`: sin reintentos automáticos; el usuario reintenta con el botón.
final sesionControllerProvider = AsyncNotifierProvider<SesionController, Usuario?>(
  SesionController.new,
  retry: (_, _) => null,
);
