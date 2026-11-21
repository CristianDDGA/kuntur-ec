import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../models/avion.dart';
import 'con_sesion.dart';

/// Aviones registrados (para elegir uno al crear un vuelo y para ver qué hay cargado).
final avionesProvider = FutureProvider.autoDispose<List<Avion>>(
  (ref) => conSesion(ref, () => ref.read(avionServiceProvider).listar()),
);

/// Estado de la pantalla "Importar aviones": archivo elegido, su revisión y el resultado.
class EstadoImportacion {
  const EstadoImportacion({
    this.nombreArchivo,
    this.csv,
    this.resumen,
    this.resultado,
    this.cargando = false,
    this.error,
  });

  final String? nombreArchivo;
  final String? csv;
  final ResumenCsv? resumen;
  final ResultadoImportacion? resultado;
  final bool cargando;
  final Object? error;

  EstadoImportacion copiar({
    String? nombreArchivo,
    String? csv,
    ResumenCsv? resumen,
    ResultadoImportacion? resultado,
    bool? cargando,
    Object? error,
  }) =>
      EstadoImportacion(
        nombreArchivo: nombreArchivo ?? this.nombreArchivo,
        csv: csv ?? this.csv,
        resumen: resumen ?? this.resumen,
        resultado: resultado ?? this.resultado,
        cargando: cargando ?? this.cargando,
        error: error,
      );
}

/// Controlador (C) de la importación: primero revisa el archivo (sin guardar) y solo si está limpio lo importa.
class ImportarAvionesController extends Notifier<EstadoImportacion> {
  @override
  EstadoImportacion build() => const EstadoImportacion();

  /// Archivo nuevo: se descarta lo anterior y se revisa en el servidor.
  Future<void> elegirArchivo(String nombre, String contenido) async {
    if (state.cargando) return;
    state = EstadoImportacion(nombreArchivo: nombre, csv: contenido, cargando: true);
    try {
      final resumen = await conSesion(ref, () => ref.read(avionServiceProvider).validar(contenido));
      if (!ref.mounted) return;
      state = state.copiar(resumen: resumen, cargando: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = EstadoImportacion(nombreArchivo: nombre, error: e);
    }
  }

  /// Guarda los aviones. Con doble toque, el segundo se ignora (nunca se importa dos veces).
  Future<void> importar() async {
    final csv = state.csv;
    if (state.cargando || csv == null || !(state.resumen?.sePuedeImportar ?? false)) return;
    state = state.copiar(cargando: true);
    try {
      final resultado = await conSesion(ref, () => ref.read(avionServiceProvider).importar(csv));
      if (!ref.mounted) return;
      ref.invalidate(avionesProvider); // el selector de aviones debe mostrar los nuevos
      state = state.copiar(resultado: resultado, cargando: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copiar(cargando: false, error: e);
    }
  }

  void reiniciar() => state = const EstadoImportacion();
}

final importarAvionesControllerProvider = NotifierProvider.autoDispose<ImportarAvionesController, EstadoImportacion>(
  ImportarAvionesController.new,
);
