import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/validadores_vuelo.dart';

/// Simula al usuario escribiendo una tecla a la vez: cada formateador recibe (texto anterior, texto nuevo).
String _teclear(List<TextInputFormatter> formateadores, String teclas, {String inicial = ''}) {
  var valor = TextEditingValue(text: inicial);
  for (final tecla in teclas.split('')) {
    var nuevo = TextEditingValue(text: valor.text + tecla);
    for (final f in formateadores) {
      nuevo = f.formatEditUpdate(valor, nuevo);
    }
    valor = nuevo;
  }
  return valor.text;
}

/// Simula borrar el último carácter [veces] veces.
String _borrar(List<TextInputFormatter> formateadores, String texto, int veces) {
  var valor = TextEditingValue(text: texto);
  for (var i = 0; i < veces && valor.text.isNotEmpty; i++) {
    var nuevo = TextEditingValue(text: valor.text.substring(0, valor.text.length - 1));
    for (final f in formateadores) {
      nuevo = f.formatEditUpdate(valor, nuevo);
    }
    valor = nuevo;
  }
  return valor.text;
}

void main() {
  group('capacidad: entero de 1 a 900', () {
    final f = ValidadoresVuelo.entradaCapacidad;

    test('deja escribir hasta 900', () => expect(_teclear(f, '900'), '900'));
    test('no deja pasar de 900', () {
      expect(_teclear(f, '901'), '90');
      expect(_teclear(f, '999'), '99');
      expect(_teclear(f, '1000'), '100');
    });
    test('no deja empezar con cero', () {
      expect(_teclear(f, '0'), '');
      expect(_teclear(f, '007'), '7');
    });
    test('ignora letras, signos, puntos, espacios y emojis', () {
      expect(_teclear(f, 'a1-2.3 😀'), '123');
      expect(_teclear(f, '٣'), '');
    });
    test('borrar siempre funciona, hasta dejar el campo vacío', () {
      expect(_borrar(f, '123', 1), '12');
      expect(_borrar(f, '123', 3), '');
      expect(_borrar(f, '900', 2), '9');
    });
    test('se puede escribir de nuevo después de vaciar', () {
      expect(_teclear(f, '45', inicial: _borrar(f, '123', 3)), '45');
    });
  });

  group('precio: hasta 10000 con 2 decimales', () {
    final f = ValidadoresVuelo.entradaPrecio;

    test('acepta montos normales', () {
      expect(_teclear(f, '75.50'), '75.50');
      expect(_teclear(f, '75,5'), '75,5');
      expect(_teclear(f, '10000'), '10000');
      expect(_teclear(f, '0.99'), '0.99');
    });
    test('no deja pasar de 10000', () {
      expect(_teclear(f, '10001'), '1000');
      expect(_teclear(f, '99999'), '9999');
      expect(_teclear(f, '10000.5'), '10000.'); // el 5 haría 10000.5, más del máximo
    });
    test('no deja escribir un tercer decimal', () => expect(_teclear(f, '75.555'), '75.55'));
    test('no deja un segundo punto ni mezclar punto y coma', () {
      expect(_teclear(f, '7.5.5'), '7.55');
      expect(_teclear(f, '7.5,5'), '7.55');
    });
    test('no deja empezar con punto, con ceros a la izquierda ni con signos', () {
      expect(_teclear(f, '.5'), '5');
      expect(_teclear(f, '007'), '0');
      expect(_teclear(f, '-5'), '5');
      expect(_teclear(f, '+5'), '5');
      expect(_teclear(f, '1e3'), '13');
    });
    test('ignora letras y emojis', () => expect(_teclear(f, 'ab7😀5'), '75'));
    test('borrar siempre funciona, incluso el punto decimal', () {
      expect(_borrar(f, '75.50', 5), '');
      expect(_borrar(f, '9999.99', 3), '9999');
      // Quitar el punto de "9999.9" daría 99999 (mayor al máximo), pero borrar nunca se bloquea.
      final sinPunto = f.first.formatEditUpdate(const TextEditingValue(text: '9999.9'), const TextEditingValue(text: '99999'));
      expect(sinPunto.text, '99999');
    });
  });

  group('porcentaje: 0 a 100', () {
    final f = ValidadoresVuelo.entradaPorcentaje;

    test('acepta 0, 12.5 y 100', () {
      expect(_teclear(f, '0'), '0');
      expect(_teclear(f, '12.5'), '12.5');
      expect(_teclear(f, '100'), '100');
    });
    test('no deja pasar de 100 ni escribir 3 decimales', () {
      expect(_teclear(f, '101'), '10');
      expect(_teclear(f, '999'), '99');
      expect(_teclear(f, '12.345'), '12.34');
      expect(_teclear(f, '100.5'), '100.');
    });
    test('no deja negativos ni letras', () => expect(_teclear(f, '-1a5'), '15'));
  });

  group('nombres de ciudad', () {
    final f = ValidadoresVuelo.entradaCiudad;

    test('bloquea emojis, números y símbolos', () => expect(_teclear(f, 'Qu1to 😀<>;'), 'Quto '));
    test('corta en 80 caracteres', () => expect(_teclear(f, 'a' * 200).length, 80));
    test('acepta tildes, eñes, apóstrofes y guiones', () => expect(_teclear(f, "Año-Nuevo D'Ávila"), "Año-Nuevo D'Ávila"));
  });
}
