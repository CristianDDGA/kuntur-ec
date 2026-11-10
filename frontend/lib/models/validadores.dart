import 'dart:convert';

/// Reglas de validación de los formularios.
///
/// Reflejan las del backend (`backend/utils/validaciones.py` y `utils/limites.py`) para que
/// el usuario vea el error antes de enviar. El backend vuelve a validar todo: estas
/// reglas mejoran la experiencia, no reemplazan la seguridad del servidor.
class Validadores {
  const Validadores._();

  // Largos = columnas de la base de datos (usuarios.nombre 100, usuarios.correo 150).
  static const int nombreMax = 100;
  static const int correoMax = 150;
  static const int passwordMin = 8;
  static const int passwordMax = 128;
  static const int passwordBytesMax = 72; // bcrypt solo considera los primeros 72 bytes

  static final RegExp _nombre = RegExp(r"^[\p{L}\p{M} .'’-]+$", unicode: true);
  static final RegExp _letraUnicode = RegExp(r'\p{L}', unicode: true);
  static final RegExp _control = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
  static final RegExp _correo = RegExp(
    r'^[A-Za-z0-9._%+-]{1,64}@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}$',
  );

  /// Nombre de persona: letras (con tildes), espacios, apóstrofes, puntos y guiones.
  static String? nombre(String? valor) {
    // Primero los caracteres de control del texto original (saltos de línea, tabuladores, NUL):
    // si se normalizaran antes, un nombre con salto de línea pasaría como si fuera
    // "Ana Torres" y el servidor lo rechazaría.
    if (_control.hasMatch(valor ?? '')) return 'Contiene caracteres no permitidos.';
    final texto = normalizarNombre(valor);
    if (texto.isEmpty) return 'Ingrese su nombre completo.';
    if (texto.length > nombreMax) return 'No puede superar $nombreMax caracteres.';
    if (!_nombre.hasMatch(texto)) {
      return 'Use solo letras, espacios, apóstrofes, puntos y guiones.';
    }
    if (_letraUnicode.allMatches(texto).length < 2) return 'Debe tener al menos 2 letras.';
    return null;
  }

  /// Quita espacios sobrantes: "  Ana   Torres " -> "Ana Torres".
  static String normalizarNombre(String? valor) =>
      (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? correo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Ingrese su correo.';
    if (texto.length > correoMax) return 'No puede superar $correoMax caracteres.';
    if (!esCorreo(texto)) return 'Ingrese un correo válido, por ejemplo nombre@correo.com.';
    return null;
  }

  static bool esCorreo(String texto) {
    if (texto.contains('..') || !_correo.hasMatch(texto)) return false;
    final local = texto.split('@').first;
    return !local.startsWith('.') && !local.endsWith('.');
  }

  /// Contraseña al CREAR la cuenta: 8–128 caracteres con letras y números.
  static String? password(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Ingrese una contraseña.';
    if (texto.length < passwordMin) return 'Debe tener al menos $passwordMin caracteres.';
    final comun = _passwordComun(texto);
    if (comun != null) return comun;
    if (utf8.encode(texto).length > passwordBytesMax) return 'Es demasiado larga.';
    final requisitos = requisitosPassword(texto);
    if (!requisitos.letra || !requisitos.numero) return 'Debe combinar letras y números.';
    return null;
  }

  /// Contraseña al INGRESAR: solo se exige que exista y sea razonable (no se revela la regla de creación).
  static String? passwordIngreso(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Ingrese su contraseña.';
    return _passwordComun(texto);
  }

  static String? _passwordComun(String texto) {
    if (texto.length > passwordMax) return 'No puede superar $passwordMax caracteres.';
    if (_control.hasMatch(texto)) return 'Contiene caracteres no permitidos.';
    return null;
  }

  /// Para la lista de requisitos que se marca mientras el usuario escribe.
  static ({bool largo, bool letra, bool numero}) requisitosPassword(String texto) => (
        largo: texto.length >= passwordMin,
        letra: RegExp(r'[A-Za-z]').hasMatch(texto),
        numero: RegExp(r'[0-9]').hasMatch(texto),
      );

  static String? Function(String?) confirmacion(String Function() original) => (valor) {
        if ((valor ?? '').isEmpty) return 'Repita la contraseña.';
        if (valor != original()) return 'Las contraseñas no coinciden.';
        return null;
      };
}
