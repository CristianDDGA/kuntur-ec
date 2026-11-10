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
