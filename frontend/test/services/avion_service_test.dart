import 'package:flutter_test/flutter_test.dart';
import 'package:vuelos_app/services/api_exception.dart';
import 'package:vuelos_app/services/avion_service.dart';

import '../helpers/fakes.dart';

const _resumenLimpio = {
  'total_filas': 2,
  'nuevos': 1,
  'existentes': ['HC-XYZ'],
  'con_errores': 0,
  'errores': [],
  'vista_previa': [
    {'linea': 2, 'matricula': 'HC-ABC', 'modelo': 'Airbus A320', 'filas': 30, 'capacidad': 120, 'ya_existe': false},
    {'linea': 3, 'matricula': 'HC-XYZ', 'modelo': 'ATR 72', 'filas': 18, 'capacidad': 72, 'ya_existe': true},
  ],
};

const _csv = 'matricula;modelo;filas\nHC-ABC;Airbus A320;30\n';

void main() {
  test('listar convierte los aviones con su capacidad', () async {
    final aviones = await AvionService(RouteFakeRestClient({'GET /aviones': listaAviones})).listar();
    expect(aviones.single.matricula, 'HC-ABC');
    expect(aviones.single.capacidad, 80);
    expect(aviones.single.etiqueta, 'HC-ABC · Airbus A320 · 80 asientos');
  });

  test('una respuesta mal formada es un error, no un crash', () {
    final api = RouteFakeRestClient({'GET /aviones': {'total': 1, 'aviones': [{'id': 'x'}]}});
    expect(AvionService(api).listar(), throwsA(isA<InvalidResponseFailure>()));
  });

  test('validar envía el CSV como texto y lee la vista previa', () async {
    final api = RouteFakeRestClient({'POST /aviones/importacion/validar': _resumenLimpio});
    final resumen = await AvionService(api).validar(_csv);

    expect(api.llamada('POST', '/aviones/importacion/validar').cuerpo, _csv); // texto, no JSON
    expect(resumen.nuevos, 1);
    expect(resumen.existentes, ['HC-XYZ']);
    expect(resumen.vistaPrevia.last.yaExiste, isTrue);
    expect(resumen.sePuedeImportar, isTrue);
  });

  test('con errores o sin aviones nuevos no se puede importar', () async {
    final conErrores = {
      ..._resumenLimpio,
      'errores': [{'linea': 3, 'mensaje': 'Matrícula inválida.'}],
    };
    final api = RouteFakeRestClient({'POST /aviones/importacion/validar': conErrores});
    final resumen = await AvionService(api).validar(_csv);
    expect(resumen.tieneErrores, isTrue);
    expect(resumen.errores.single.linea, 3);
    expect(resumen.sePuedeImportar, isFalse);

    final sinNuevos = RouteFakeRestClient({
      'POST /aviones/importacion/validar': {..._resumenLimpio, 'nuevos': 0},
    });
    expect((await AvionService(sinNuevos).validar(_csv)).sePuedeImportar, isFalse);
  });

  test('importar devuelve cuántos se crearon y cuáles se omitieron', () async {
    final api = RouteFakeRestClient({
      'POST /aviones/importacion': {'mensaje': 'ok', 'creados': 1, 'omitidos': ['HC-XYZ'], 'total_filas': 2},
    });
    final resultado = await AvionService(api).importar(_csv);
    expect(resultado.creados, 1);
    expect(resultado.omitidos, ['HC-XYZ']);
  });
}
