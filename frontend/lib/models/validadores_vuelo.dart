import 'package:flutter/services.dart';

import 'validadores.dart';
import 'vuelo.dart';

/// Deja escribir solo números que siguen [patron] y no pasan de [maximo]; lo demás se ignora
/// (la tecla simplemente no escribe). **Borrar siempre se permite**, aunque el texto que quede
/// sea incompleto: así el usuario nunca queda atrapado sin poder corregir un campo.
class EntradaNumerica extends TextInputFormatter {
  const EntradaNumerica({required this.patron, required this.maximo});

  final RegExp patron;
  final double maximo;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    if (nuevo.text.length < anterior.text.length || nuevo.text.isEmpty) return nuevo;
    if (!patron.hasMatch(nuevo.text)) return anterior;
    final numero = double.tryParse(nuevo.text.replaceAll(',', '.'));
    if (numero == null || numero > maximo) return anterior;
    return nuevo;
  }
}

/// Reglas de los formularios de vuelos. Reflejan `backend/services/vuelo_service.py`,
/// `utils/validaciones.py` y `utils/limites.py` (el servidor vuelve a validar todo).
class ValidadoresVuelo {
  const ValidadoresVuelo._();

  // Largo = columna de la base (vuelos.origen/destino 80). El código lo genera el servidor.
  static const int ciudadMax = 80;
  static const int capacidadMax = 200;
  static const int precioMaxCentavos = 10000 * 100;
  static const int diasMaxAdelante = 730;

  static final RegExp _ciudad = RegExp(r"^[\p{L}\p{M} .'’-]+$", unicode: true);
  static final RegExp _letra = RegExp(r'\p{L}', unicode: true);
  static final RegExp _control = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
  static final RegExp _precio = RegExp(r'^\d{1,8}(?:\.\d{1,2})?$');
  static final RegExp _porcentaje = RegExp(r'^\d{1,3}(?:\.\d{1,2})?$');

  static final RegExp _patronPrecio = RegExp(r'^(0|[1-9]\d{0,4})([.,]\d{0,2})?$');
  static final RegExp _patronCapacidad = RegExp(r'^[1-9]\d{0,2}$');
  static final RegExp _patronPorcentaje = RegExp(r'^(0|[1-9]\d{0,2})([.,]\d{0,2})?$');

  /// Precio: hasta 10000 con 2 decimales, sin ceros a la izquierda.
  static final List<TextInputFormatter> entradaPrecio = [
    EntradaNumerica(patron: _patronPrecio, maximo: precioMaxCentavos / 100),
  ];

  /// Asientos: entero de 1 a [capacidadMax], sin ceros a la izquierda.
  static final List<TextInputFormatter> entradaCapacidad = [
    EntradaNumerica(patron: _patronCapacidad, maximo: capacidadMax * 1.0),
  ];

  /// Porcentaje de IVA: de 0 a 100 con hasta 2 decimales.
  static final List<TextInputFormatter> entradaPorcentaje = [
    EntradaNumerica(patron: _patronPorcentaje, maximo: 100),
  ];

  /// Origen y destino: solo letras, espacios, apóstrofes, puntos y guiones, hasta [ciudadMax].
  static List<TextInputFormatter> get entradaCiudad => Validadores.entradaNombre(ciudadMax);

  /// "  Quito   " -> "Quito".
  static String normalizarTexto(String? valor) =>
      (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? ciudad(String? valor, {String nombre = 'La ciudad'}) {
    if (_control.hasMatch(valor ?? '')) return 'Contiene caracteres no permitidos.';
    final texto = normalizarTexto(valor);
    if (texto.isEmpty) return '$nombre es obligatorio.';
    if (texto.length > ciudadMax) return 'No puede superar $ciudadMax caracteres.';
    if (!_ciudad.hasMatch(texto)) return 'Use solo letras, espacios, apóstrofes, puntos y guiones.';
    if (_letra.allMatches(texto).length < 2) return 'Debe tener al menos 2 letras.';
    return null;
  }

  /// Filtro de búsqueda: opcional, pero si se escribe sigue las reglas de una ciudad.
  static String? filtroCiudad(String? valor) {
    if (normalizarTexto(valor).isEmpty) return null;
    return ciudad(valor);
  }

  static String? destinoDistinto(String? destino, String? origen) {
    final error = ciudad(destino, nombre: 'El destino');
    if (error != null) return error;
    if (normalizarTexto(destino).toLowerCase() == normalizarTexto(origen).toLowerCase()) {
      return 'Debe ser distinto del origen.';
    }
    return null;
  }

  static String? precio(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    if (texto.isEmpty) return 'El precio es obligatorio.';
    if (!_precio.hasMatch(texto)) return 'Escriba un monto con hasta 2 decimales, por ejemplo 75.50.';
    final partes = texto.split('.');
    final centavos = int.parse(partes[0]) * 100 + int.parse((partes.length > 1 ? partes[1] : '').padRight(2, '0'));
    if (centavos <= 0) return 'Debe ser mayor a 0.';
    if (centavos > precioMaxCentavos) return 'No puede superar \$10000.';
    return null;
  }

  /// Texto del precio listo para enviar a la API ("75,5" -> "75.5").
  static String normalizarPrecio(String valor) => valor.trim().replaceAll(',', '.');

  static String? capacidad(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'La capacidad es obligatoria.';
    final n = int.tryParse(texto);
    if (n == null || !RegExp(r'^\d+$').hasMatch(texto)) return 'Escriba un número entero.';
    if (n < 1 || n > capacidadMax) return 'Debe estar entre 1 y $capacidadMax.';
    return null;
  }

  /// La fecha debe ser desde hoy hasta 2 años adelante. [hoy] se inyecta en las pruebas.
  static String? fecha(DateTime? valor, {DateTime? hoy}) {
    if (valor == null) return 'Elija la fecha del vuelo.';
    final h = hoy ?? DateTime.now();
    final dia = DateTime(h.year, h.month, h.day);
    if (valor.isBefore(dia)) return 'No puede ser una fecha pasada.';
    if (valor.isAfter(dia.add(const Duration(days: diasMaxAdelante)))) {
      return 'No puede superar los 2 años desde hoy.';
    }
    return null;
  }

  static String? hora(Duration? valor, {String nombre = 'La hora'}) =>
      valor == null ? '$nombre es obligatoria.' : null;

  static String? llegada(Duration? llegada, Duration? salida) {
    if (llegada == null) return 'La hora de llegada es obligatoria.';
    if (salida != null && llegada == salida) return 'Debe ser distinta a la de salida.';
    return null;
  }

  /// Hora de salida: obligatoria y, si el vuelo es hoy, posterior a la hora actual. [ahora] se inyecta en pruebas.
  static String? salida(Duration? salida, DateTime? fecha, {DateTime? ahora}) {
    if (salida == null) return 'La hora de salida es obligatoria.';
    if (fecha == null) return null;
    final ya = ahora ?? DateTime.now();
    final esHoy = fecha.year == ya.year && fecha.month == ya.month && fecha.day == ya.day;
    final actual = Duration(hours: ya.hour, minutes: ya.minute);
    if (esHoy && salida <= actual) {
      return 'Esa hora ya pasó. Elija una posterior a las ${Formatos.hora(actual)}.';
    }
    return null;
  }

  /// Porcentaje de IVA: 0 a 100 con hasta 2 decimales (acepta coma o punto).
  static String? porcentaje(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    if (texto.isEmpty) return 'Escriba el porcentaje.';
    if (!_porcentaje.hasMatch(texto)) return 'Escriba un número con hasta 2 decimales, por ejemplo 15 o 12.5.';
    if (double.parse(texto) > 100) return 'No puede superar 100.';
    return null;
  }

  /// Fecha de inicio de una tarifa: desde hoy hasta 2 años (igual que una fecha de vuelo).
  static String? inicioTarifa(DateTime? valor, {DateTime? hoy}) =>
      valor == null ? 'Elija desde cuándo rige.' : fecha(valor, hoy: hoy);
}
