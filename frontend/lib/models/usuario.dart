import '../services/api_exception.dart';
import '../services/rest_client.dart';

enum Rol { cliente, admin }

/// Usuario autenticado. Contrato: {"id", "nombre", "correo", "rol", "fecha_registro"}.
/// La API nunca envía la contraseña.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.fechaRegistro,
  });

  factory Usuario.fromJson(JsonMap json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final correo = json['correo'];
    final rol = Rol.values.asNameMap()[json['rol']];
    if (id is! int || nombre is! String || correo is! String || rol == null) {
      throw const InvalidResponseFailure();
    }
    return Usuario(
      id: id,
      nombre: nombre,
      correo: correo,
      rol: rol,
      fechaRegistro: DateTime.tryParse(json['fecha_registro']?.toString() ?? ''),
    );
  }

  final int id;
  final String nombre;
  final String correo;
  final Rol rol;
  final DateTime? fechaRegistro;

  bool get esAdmin => rol == Rol.admin;

  /// "Ana Torres" -> "AT"; "Ana" -> "A".
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}
