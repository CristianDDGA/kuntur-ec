import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';

/// Controlador (C de MVC) de la sesión: quién está autenticado.
///
/// El estado es el [Usuario] actual o `null` si no hay sesión. El router lo observa
/// para decidir a qué pantallas se puede entrar.
class SesionController extends AsyncNotifier<Usuario?> {
  /// Al arrancar la app: si hay un token guardado se valida con el servidor
  /// (`GET /auth/perfil`) y así una sesión vencida o revocada no deja pasar a nadie.
  @override
  Future<Usuario?> build() async {
    final auth = ref.read(authServiceProvider);
    if (!await auth.tieneToken()) return null;
    try {
      return await auth.perfil();
    } on UnauthorizedFailure {
      await auth.descartarToken();
      return null;
    }
    // Cualquier otro fallo (sin conexión, servidor caído) se propaga: la pantalla de carga
    // ofrece reintentar y el token se conserva para no cerrar la sesión por un corte de red.
  }

  /// Lo llaman el login y el registro cuando ya tienen un usuario autenticado.
  void abrir(Usuario usuario) => state = AsyncData(usuario);

  Future<void> cerrarSesion() async {
    await ref.read(authServiceProvider).cerrarSesion();
    state = const AsyncData(null);
  }

  /// Para los demás controladores: una petición devolvió 401, la sesión ya no es válida.
  Future<void> sesionExpirada() async {
    await ref.read(authServiceProvider).descartarToken();
    state = const AsyncData(null);
  }

  /// Desde la pantalla de carga cuando el servidor no responde: seguir hacia el login.
  void continuarSinSesion() => state = const AsyncData(null);
}

/// `retry: null`: sin reintentos automáticos; el usuario reintenta con el botón.
final sesionControllerProvider = AsyncNotifierProvider<SesionController, Usuario?>(
  SesionController.new,
  retry: (_, _) => null,
);
