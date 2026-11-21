import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/validadores.dart';

void main() {
  group('nombre', () {
    for (final valido in ['Ana Torres', 'José Ñandú', "O'Brien-Pérez", 'María de los Ángeles', 'Dr. Juan', 'Zoë', '李小龙']) {
      test('acepta "$valido"', () => expect(Validadores.nombre(valido), isNull));
    }

    test('normaliza espacios antes de validar', () {
      expect(Validadores.nombre('  Ana   Torres '), isNull);
      expect(Validadores.normalizarNombre('  Ana   Torres '), 'Ana Torres');
    });

    final invalidos = {
      'emoji': 'Ana 😀',
      'solo emojis': '😀😀😀',
      'script': '<script>alert(1)</script>',
      'SQL': "Robert'); DROP TABLE usuarios;--",
      'números': 'Ana123',
      'símbolos': 'Ana #\$%',
      'salto de línea': 'Ana\nTorres',
      'tabulador': 'Ana\tTorres',
      'NUL': 'Ana\u0000Torres',
      'una letra': 'A',
      'solo signos': '- - -',
      'arroba': 'Ana@Torres',
    };
    invalidos.forEach((nombre, valor) {
      test('rechaza $nombre', () => expect(Validadores.nombre(valor), isNotNull));
    });

    test('exige el campo y respeta el largo de la columna (100)', () {
      expect(Validadores.nombre(null), 'Ingrese su nombre completo.');
      expect(Validadores.nombre('   '), 'Ingrese su nombre completo.');
      expect(Validadores.nombre('A' * 100), isNull);
      expect(Validadores.nombre('A' * 101), contains('100'));
    });
  });

  group('cédula', () {
    // Los dígitos verificadores se calculan aquí con el mismo módulo 10, no se memorizan.
    String completar(String nueve) {
      var suma = 0;
      for (var i = 0; i < 9; i++) {
        final p = int.parse(nueve[i]) * (i.isEven ? 2 : 1);
        suma += p > 9 ? p - 9 : p;
      }
      return '$nueve${(10 - suma % 10) % 10}';
    }

    test('acepta una cédula con verificador correcto', () {
      expect(Validadores.cedula('1710034065'), isNull);
      expect(Validadores.cedula(' 1710034065 '), isNull); // los extremos se recortan
    });

    test('cambiar un solo dígito la invalida', () {
      const valida = '1710034065';
      for (var i = 0; i < 10; i++) {
        for (final d in '0123456789'.split('')) {
          if (d == valida[i]) continue;
          final otra = valida.substring(0, i) + d + valida.substring(i + 1);
          expect(Validadores.esCedula(otra), isFalse, reason: otra);
        }
      }
    });

    test('acepta las provincias 01-24 y 30, rechaza las demás', () {
      for (final p in [...List.generate(24, (i) => i + 1), 30]) {
        expect(Validadores.esCedula(completar('${p.toString().padLeft(2, '0')}1003406')), isTrue, reason: '$p');
      }
      for (final p in [0, 25, 31, 99]) {
        expect(Validadores.esCedula(completar('${p.toString().padLeft(2, '0')}1003406')), isFalse, reason: '$p');
      }
    });

    test('el tercer dígito debe ser menor que 6', () {
      expect(Validadores.esCedula(completar('171003406')), isTrue);
      expect(Validadores.esCedula(completar('176003406')), isFalse);
    });

    test('mensajes: vacía, con letras, corta y con verificador mal', () {
      expect(Validadores.cedula(''), 'Ingrese su número de cédula.');
      expect(Validadores.cedula('17100a4065'), 'La cédula solo lleva números.');
      expect(Validadores.cedula('171003'), 'La cédula tiene 10 dígitos.');
      expect(Validadores.cedula('1710034066'), contains('no es válida'));
    });
  });

  group('código de verificación', () {
    test('acepta exactamente 6 dígitos (con espacios en los extremos)', () {
      expect(Validadores.codigoVerificacion('123456'), isNull);
      expect(Validadores.codigoVerificacion(' 123456 '), isNull);
    });

    test('rechaza vacío, corto, largo y con letras', () {
      expect(Validadores.codigoVerificacion(''), 'Ingrese el código que le enviamos.');
      expect(Validadores.codigoVerificacion('12345'), 'El código tiene 6 dígitos.');
      expect(Validadores.codigoVerificacion('1234567'), 'El código tiene 6 dígitos.');
      expect(Validadores.codigoVerificacion('12345a'), 'El código tiene 6 dígitos.');
    });
  });

  group('correo', () {
    for (final valido in ['ana@correo.com', 'a.b+c@sub.dominio.ec', 'A_B-1@x.co', '  ana@correo.com  ']) {
      test('acepta "$valido"', () => expect(Validadores.correo(valido), isNull));
    }

    for (final invalido in [
      'ana😀@correo.com', 'ana torres@correo.com', "' OR 1=1 --@x.com", '<script>@x.com', 'ana@', 'a@b@c.com',
      'ana@correo', '@correo.com', '.ana@correo.com', 'ana.@correo.com', 'ana..t@correo.com', 'ana@-.com',
      'ñandú@correo.com', 'ana@correo.c',
    ]) {
      test('rechaza "$invalido"', () => expect(Validadores.correo(invalido), isNotNull));
    }

    test('exige el campo y respeta el largo de la columna (150)', () {
      expect(Validadores.correo(''), 'Ingrese su correo.');
      final en150 = '${'a' * 64}@${'b' * 63}.${'d' * 17}.com';
      expect(en150.length, 150);
      expect(Validadores.correo(en150), isNull);
      expect(Validadores.correo('${en150}m'), contains('150'));
    });
  });

  group('contraseña al crear la cuenta', () {
    test('acepta 8+ caracteres con letras y números (también símbolos y emojis)', () {
      expect(Validadores.password('Clave2026'), isNull);
      expect(Validadores.password('Cl@ve#2026!'), isNull);
      expect(Validadores.password('Clave😀2026'), isNull);
    });

    test('rechaza las que no cumplen', () {
      expect(Validadores.password(''), 'Ingrese una contraseña.');
      expect(Validadores.password('Ab1'), contains('al menos 8'));
      expect(Validadores.password('solamenteletras'), 'Debe combinar letras y números.');
      expect(Validadores.password('12345678'), 'Debe combinar letras y números.');
      expect(Validadores.password('Clave\n2026'), 'Contiene caracteres no permitidos.');
      expect(Validadores.password('Clave\u00002026'), 'Contiene caracteres no permitidos.');
      expect(Validadores.password('A1${'x' * 80}'), 'Es demasiado larga.'); // más de 72 bytes (bcrypt)
      expect(Validadores.password('A1${'x' * 130}'), contains('128'));
    });

    test('la lista de requisitos refleja lo escrito', () {
      expect(Validadores.requisitosPassword(''), (largo: false, letra: false, numero: false));
      expect(Validadores.requisitosPassword('abc'), (largo: false, letra: true, numero: false));
      expect(Validadores.requisitosPassword('abcdefg1'), (largo: true, letra: true, numero: true));
    });
  });

  group('contraseña al ingresar', () {
    test('solo exige que exista y sea razonable (no revela la regla de creación)', () {
      expect(Validadores.passwordIngreso('corta'), isNull);
      expect(Validadores.passwordIngreso(''), 'Ingrese su contraseña.');
      expect(Validadores.passwordIngreso('a\u0000b'), isNotNull);
      expect(Validadores.passwordIngreso('A' * 129), isNotNull);
    });
  });

  test('confirmación compara con la contraseña actual', () {
    var actual = 'Clave2026';
    final validar = Validadores.confirmacion(() => actual);
    expect(validar(''), 'Repita la contraseña.');
    expect(validar('Clave2027'), 'Las contraseñas no coinciden.');
    expect(validar('Clave2026'), isNull);
    actual = 'Otra2026'; // si cambia la contraseña, la confirmación se evalúa contra la nueva
    expect(validar('Clave2026'), 'Las contraseñas no coinciden.');
  });
}
