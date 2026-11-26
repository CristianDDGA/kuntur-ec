import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/aviones_controller.dart';
import '../models/avion.dart';
import '../models/fallo.dart';
import '../models/vuelo.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/estado_vista.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/skeleton_kuntur.dart';

const int _maxBytesCsv = 1024 * 1024;

/// Importar aviones desde un CSV (V). Vista previa acotada con scroll virtualizado y esqueletos.
class ImportarAvionesPage extends ConsumerWidget {
  const ImportarAvionesPage({super.key});

  Future<void> _elegir(BuildContext context, WidgetRef ref) async {
    final controlador = ref.read(importarAvionesControllerProvider.notifier);
    final elegidos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    final elegido = elegidos.firstOrNull;
    if (elegido == null) return;
    final bytes = await elegido.readAsBytes();
    if (bytes.isEmpty) {
      if (context.mounted) {
        mostrarAviso(context, 'No se pudo leer el archivo.');
      }
      return;
    }
    if (bytes.length > _maxBytesCsv) {
      if (context.mounted) {
        mostrarAviso(context, 'El archivo supera 1 MB.');
      }
      return;
    }
    try {
      await controlador.elegirArchivo(elegido.name, utf8.decode(bytes));
    } on FormatException {
      if (context.mounted) {
        mostrarAviso(context, 'El archivo debe estar codificado en UTF-8.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(importarAvionesControllerProvider);
    final aviones = ref.watch(avionesProvider);
    final error = estado.error == null ? null : mensajeDeError(estado.error!);
    final resumen = estado.resumen;

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.administracion,
      maxAncho: 900,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Migas([
            Miga('Administración', ruta: AppRoutes.admin),
            Miga('Importar aviones'),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: AppDecorations.tarjeta,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Importar aviones', style: AppTextStyles.titulo),
                const SizedBox(height: 4),
                const Text(
                  'Suba un archivo CSV con el encabezado matricula;modelo;filas. Cada fila del avión tiene 4 asientos '
                  '(A–D), de 1 a 50 filas. Antes de guardar se revisa y se muestran los errores por línea.',
                  style: AppTextStyles.cuerpo,
                ),
                const SizedBox(height: 16),
                BotonDegradado(
                  texto: estado.nombreArchivo == null ? 'Elegir archivo CSV' : 'Elegir otro archivo',
                  cargando: estado.cargando && resumen == null,
                  onPressed: estado.cargando ? null : () => _elegir(context, ref),
                ),
                if (estado.nombreArchivo != null) ...[
                  const SizedBox(height: 8),
                  Tooltip(
                    message: estado.nombreArchivo!,
                    child: Text(
                      'Archivo: ${estado.nombreArchivo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.nota,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  AvisoInline(texto: error),
                ],
                if (estado.resultado != null) ...[
                  const SizedBox(height: 16),
                  _Resultado(resultado: estado.resultado!),
                ] else if (resumen != null) ...[
                  const SizedBox(height: 16),
                  _Revision(resumen: resumen),
                  const SizedBox(height: 16),
                  BotonDegradado(
                    texto: resumen.nuevos == 1
                        ? 'Importar 1 avión'
                        : 'Importar ${Formatos.entero(resumen.nuevos)} aviones',
                    cargando: estado.cargando,
                    onPressed: resumen.sePuedeImportar && !estado.cargando
                        ? () => ref.read(importarAvionesControllerProvider.notifier).importar()
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Registrados(aviones: aviones, onReintentar: () => ref.invalidate(avionesProvider)),
        ],
      ),
    );
  }
}

class _Revision extends StatelessWidget {
  const _Revision({required this.resumen});

  final ResumenCsv resumen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resumen.tieneErrores)
          AvisoInline(
            texto: 'El archivo tiene ${Formatos.entero(resumen.errores.length)} '
                '${resumen.errores.length == 1 ? 'problema' : 'problemas'}. Corríjalo y vuelva a subirlo.',
          )
        else if (resumen.nuevos == 0)
          const AvisoInline(texto: 'Todos los aviones del archivo ya están registrados.', tipo: TipoAviso.info)
        else
          AvisoInline(
            texto: 'Archivo correcto: ${Formatos.entero(resumen.nuevos)} '
                '${resumen.nuevos == 1 ? 'avión nuevo' : 'aviones nuevos'}'
                '${resumen.existentes.isEmpty ? '' : ' y ${Formatos.entero(resumen.existentes.length)} ya registrados (se omiten)'}.',
            tipo: TipoAviso.exito,
          ),
        if (resumen.errores.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: resumen.errores.length,
              itemBuilder: (_, i) {
                final e = resumen.errores[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Línea ${e.linea}: ${e.mensaje}',
                    style: const TextStyle(color: AppColors.error, fontFeatures: AppTextStyles.tabular),
                  ),
                );
              },
            ),
          ),
        ],
        if (resumen.vistaPrevia.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Vista previa', style: AppTextStyles.etiqueta),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: resumen.vistaPrevia.length,
              itemBuilder: (_, i) {
                final f = resumen.vistaPrevia[i];
                final filasTxt = f.filas == 1 ? '1 fila' : '${Formatos.entero(f.filas)} filas';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    f.yaExiste ? Icons.check_circle_outline : Icons.add_circle_outline,
                    color: f.yaExiste ? AppColors.textoSuave : AppColors.exito,
                  ),
                  title: Text('${f.matricula} · ${f.modelo}'),
                  subtitle: Text(
                    '$filasTxt · ${Formatos.entero(f.capacidad)} asientos${f.yaExiste ? ' · ya registrado' : ''}',
                    style: const TextStyle(fontFeatures: AppTextStyles.tabular),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.resultado});

  final ResultadoImportacion resultado;

  @override
  Widget build(BuildContext context) => AvisoInline(
        tipo: TipoAviso.exito,
        texto: 'Se importaron ${Formatos.entero(resultado.creados)} '
            '${resultado.creados == 1 ? 'avión' : 'aviones'}'
            '${resultado.omitidos.isEmpty ? '.' : ' y se omitieron ${Formatos.entero(resultado.omitidos.length)} que ya existían.'}',
      );
}

class _Registrados extends StatelessWidget {
  const _Registrados({required this.aviones, required this.onReintentar});

  final AsyncValue<List<Avion>> aviones;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Aviones registrados', style: AppTextStyles.subtitulo),
          const SizedBox(height: 8),
          aviones.when(
            loading: () => const SkeletonListaFilas(filas: 3),
            error: (e, _) => ErrorVista(mensaje: mensajeDeError(e), onReintentar: onReintentar),
            data: (lista) => lista.isEmpty
                ? const VacioVista(
                    icono: Icons.airplanemode_active,
                    titulo: 'Aún no hay aviones',
                    mensaje: 'Importe un CSV para poder crear vuelos.',
                    elevada: false,
                  )
                : Column(
                    children: [
                      for (final a in lista)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.airplanemode_active, color: AppColors.azul),
                          title: Text('${a.matricula} · ${a.modelo}'),
                          subtitle: Text(
                            '${a.filas == 1 ? '1 fila' : '${Formatos.entero(a.filas)} filas'} · '
                            '${Formatos.entero(a.capacidad)} asientos',
                            style: const TextStyle(fontFeatures: AppTextStyles.tabular),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
