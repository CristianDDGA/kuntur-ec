import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_boton_otros.dart' if (dart.library.js_interop) 'google_boton_web.dart';

/// Contrato para «Iniciar sesión con Google» (Inversión de Dependencias): la app no conoce el paquete de Google,
/// así que las pruebas lo reemplazan por un doble sin abrir ninguna ventana.
///
/// Lo único que la app necesita de Google es el `id_token`: se lo envía al servidor, que lo valida con las claves
/// públicas de Google. Nunca se confía en el nombre o el correo que diga el cliente.
abstract interface class ProveedorGoogle {
  /// `false` si falta el ID de cliente o la plataforma no está configurada: el botón no se muestra.
  bool get disponible;

  /// Cada `id_token` que Google entrega cuando la persona termina de iniciar sesión.
  Stream<String> get tokens;

  /// Prepara el SDK de Google. Se puede llamar varias veces.
  Future<void> iniciar();

  /// El botón que se muestra (en la web, el que dibuja Google).
  Widget boton();
}

class ProveedorGoogleReal implements ProveedorGoogle {
  ProveedorGoogleReal(this._clientId);

  final String _clientId;
  final StreamController<String> _tokens = StreamController<String>.broadcast();
  Future<void>? _iniciado;

  // Por ahora solo la web: Android e iOS necesitan sus propios ID de cliente y configuración nativa.
  @override
  bool get disponible => kIsWeb && _clientId.isNotEmpty;

  @override
  Stream<String> get tokens => _tokens.stream;

  @override
  Future<void> iniciar() => _iniciado ??= _inicializar();

  Future<void> _inicializar() async {
    final google = GoogleSignIn.instance;
    await google.initialize(clientId: _clientId);
    google.authenticationEvents.listen(
      (evento) {
        if (evento is GoogleSignInAuthenticationEventSignIn) {
          final token = evento.user.authentication.idToken;
          if (token != null && token.isNotEmpty) _tokens.add(token);
        }
      },
      // Cancelar el diálogo o cerrar la ventana no es un error para la persona: simplemente no pasa nada.
      onError: (Object _) {},
    );
  }

  @override
  Widget boton() => botonDeGoogleWeb();
}
