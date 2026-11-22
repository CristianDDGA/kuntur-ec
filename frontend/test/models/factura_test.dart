import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/models/factura.dart';
import 'package:vuelos_app/services/api_exception.dart';

import '../helpers/fakes.dart';

void main() {
  group('Factura.desdeXml', () {
    test('lee la factura que genera el servidor', () {
      final f = Factura.desdeXml(facturaXml());
      expect(f.numero, 'KEC-00000058');
      expect(f.fecha, DateTime(2026, 11, 11));
      expect(f.clienteNombre, 'Ana Torres');
      expect(f.clienteCorreo, 'ana@correo.com');
      expect(f.descripcion, contains('KT101'));
      expect(f.asientos, ['1A', '1B']);
      expect(f.cantidad, 2);
      expect((f.precioUnitarioCentavos, f.subtotalCentavos, f.ivaCentavos, f.totalCentavos), (8900, 17800, 2670, 20470));
      expect(f.ivaPorcentaje, '15.00');
      expect(f.estado, 'Confirmada');
      expect(f.anulada, isFalse);
    });

    test('conserva el XML original para mostrarlo', () {
      final xml = facturaXml();
      expect(Factura.desdeXml(xml).xml, xml);
    });

    test('una factura sin asientos (reservas antiguas) también se lee', () {
      expect(Factura.desdeXml(facturaXml(asientos: null)).asientos, isEmpty);
    });

    test('una reserva cancelada se reconoce como anulada', () {
      expect(Factura.desdeXml(facturaXml(estado: 'Cancelada')).anulada, isTrue);
    });

    test('los caracteres especiales del XML llegan como texto, no se interpretan', () {
      final f = Factura.desdeXml(facturaXml(nombre: 'Ana &lt;script&gt;alert(1)&lt;/script&gt; &amp; Co'));
      expect(f.clienteNombre, 'Ana <script>alert(1)</script> & Co');
    });

    test('los montos se leen en centavos exactos, sin decimales flotantes', () {
      final f = Factura.desdeXml(facturaXml(unitario: '0.10', subtotal: '0.30', iva: '0.05', total: '0.35', cantidad: '3'));
      expect((f.precioUnitarioCentavos, f.subtotalCentavos, f.ivaCentavos, f.totalCentavos), (10, 30, 5, 35));
    });

    test('todo lo que no sea una factura válida es InvalidResponseFailure', () {
      for (final malo in <String>[
        '',
        'esto no es xml',
        '<factura><cabecera>',
        '<otra><cosa/></otra>',
        '<factura/>',
        '{"json": true}',
        facturaXml(total: 'mucho'),
        facturaXml(cantidad: 'dos'),
        facturaXml(fecha: '11/11/2026'),
        facturaXml(porcentaje: '1500'),
        facturaXml(numero: ''),
        facturaXml(correo: ''),
        facturaXml().replaceAll('<Estado>Confirmada</Estado>', ''),
        facturaXml().replaceAll('<Totales>', '<Totales2>').replaceAll('</Totales>', '</Totales2>'),
        '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><factura>&e;</factura>',
      ]) {
        expect(() => Factura.desdeXml(malo), throwsA(isA<InvalidResponseFailure>()), reason: malo.length > 60 ? malo.substring(0, 60) : malo);
      }
    });

    test('un XML enorme no rompe el lector', () {
      final grande = facturaXml(descripcion: 'Pasaje ${'x' * 200000}');
      expect(Factura.desdeXml(grande).descripcion.length, greaterThan(200000));
    });
  });
}
