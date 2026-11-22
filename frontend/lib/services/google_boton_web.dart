import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// En la web el inicio de sesión lo dispara el botón que dibuja Google (Google Identity Services): una app no puede
/// abrir ese diálogo con un botón propio.
Widget botonDeGoogleWeb() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.pill,
        locale: 'es',
      ),
    );
