import 'dart:convert';

/// Lee la fecha de vencimiento (`exp`) de un JWT, solo para saber cuándo cerrar la sesión.
///
/// No valida la firma: eso lo hace siempre el servidor. Aquí solo se programa el aviso al usuario.
class ExpiracionToken {
  const ExpiracionToken._();

  /// Momento en que vence el token, o `null` si no se puede leer (token raro o sin `exp`).
  static DateTime? de(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return null;
    try {
      final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
      final datos = jsonDecode(carga);
      if (datos is! Map) return null;
      final exp = datos['exp'];
      if (exp is! num || !exp.isFinite || exp <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(), isUtc: true);
    } on FormatException {
      return null;
    }
  }
}
