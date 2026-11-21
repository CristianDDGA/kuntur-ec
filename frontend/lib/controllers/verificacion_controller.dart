import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../services/api_exception.dart';
import 'sesion_controller.dart';

/// Cuenta que está confirmando su correo. Lleva la contraseña **solo en memoria** para iniciar sesión sola al
/// terminar (si se recarga la página se pierde y la persona inicia sesión a mano).
class VerificacionPendiente {
  const VerificacionPendiente({required this.correo, required this.password, this.enviarAlEntrar = false});

  final String correo;
  final String password;

  /// `true` si hay que pedir un código al abrir la pantalla: el correo del registro no salió, o la persona llegó
  /// desde el login y el código anterior pudo vencer.
  final bool enviarAlEntrar;
}

class VerificacionPendienteController extends Notifier<VerificacionPendiente?> {
  @override
  VerificacionPendiente? build() => null;

  void iniciar(VerificacionPendiente pendiente) => state = pendiente;
  void limpiar() => state = null;
}

final verificacionPendienteProvider =
    NotifierProvider<VerificacionPendienteController, VerificacionPendiente?>(VerificacionPendienteController.new);

/// Se lanza cuando el correo quedó verificado pero el inicio de sesión automático falló.
const codigoVerificadoSinSesion = 'verificado_sin_sesion';

/// Controlador (C) de la pantalla "Confirme su correo": envía el código y, si es correcto, inicia sesión.
class VerificarCorreoController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> verificar(String codigo) async {
    final pendiente = ref.read(verificacionPendienteProvider);
    if (pendiente == null || state.isLoading) return;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() async {
      final auth = ref.read(authServiceProvider);
      await auth.verificarCorreo(correo: pendiente.correo, codigo: codigo);
      try {
        final sesion = await auth.login(correo: pendiente.correo, password: pendiente.password);
        ref.read(verificacionPendienteProvider.notifier).limpiar();
        ref.read(sesionControllerProvider.notifier).abrir(sesion.usuario);
      } on Failure {
        ref.read(verificacionPendienteProvider.notifier).limpiar();
        throw const ServerFailure(
          'Su correo quedó verificado, pero no se pudo iniciar sesión automáticamente. Inicie sesión con su correo y contraseña.',
          statusCode: 200,
          codigo: codigoVerificadoSinSesion,
        );
      }
    });
    if (ref.mounted) state = resultado;
  }
}

final verificarCorreoControllerProvider = AsyncNotifierProvider.autoDispose<VerificarCorreoController, void>(
  VerificarCorreoController.new,
  retry: (_, _) => null,
);

/// Pedir otro código. Aparte de [VerificarCorreoController] para que un error al reenviar no tape el de verificar.
class ReenviarCodigoController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// `true` si el servidor aceptó la solicitud.
  Future<bool> reenviar() async {
    final pendiente = ref.read(verificacionPendienteProvider);
    if (pendiente == null || state.isLoading) return false;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() => ref.read(authServiceProvider).reenviarCodigo(correo: pendiente.correo));
    if (ref.mounted) state = resultado;
    return resultado.hasValue;
  }
}

final reenviarCodigoControllerProvider = AsyncNotifierProvider.autoDispose<ReenviarCodigoController, void>(
  ReenviarCodigoController.new,
  retry: (_, _) => null,
);
