import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/iva_controller.dart';
import '../controllers/resumen_ventas_controller.dart';
import '../models/fallo.dart';
import '../models/resumen_ventas.dart';
import '../models/tarifa_iva.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';
import '../widgets/campo_texto_kuntur.dart';
import '../widgets/estado_vista.dart';
import '../widgets/hoja_confirmacion.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/selectores_fecha_hora.dart';
import '../widgets/skeleton_kuntur.dart';

/// Panel del administrador (V): resumen de ventas, vuelos, flota CSV y gestión del IVA.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iva = ref.watch(ivaControllerProvider);

    return KunturScaffold(
      seccion: Seccion.administracion,
      maxAncho: 920,
      onRefrescar: () async {
        ref.invalidate(ivaControllerProvider);
        ref.invalidate(resumenVentasProvider);
        await ref.read(ivaControllerProvider.future);
      },
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Administración', style: AppTextStyles.titulo),
          const SizedBox(height: 4),
          const Text('Gestione los vuelos y el impuesto que se cobra en las reservas.', style: AppTextStyles.cuerpo),
          const SizedBox(height: 16),
          const _TarjetaResumenVentas(),
          const SizedBox(height: 16),
          _TarjetaVuelos(
            onCrear: () => context.push(AppRoutes.nuevoVuelo),
            onGestionar: () => context.push(AppRoutes.gestionVuelos),
          ),
          const SizedBox(height: 16),
          _TarjetaAviones(onImportar: () => context.push(AppRoutes.importarAviones)),
          const SizedBox(height: 16),
          if (iva.isLoading && !iva.hasValue)
            const CargandoDetalleVista()
          else if (iva.hasError && !iva.hasValue)
            ErrorVista(
              mensaje: mensajeDeError(iva.error!),
              onReintentar: () => ref.invalidate(ivaControllerProvider),
            )
          else
            _SeccionIva(resumen: iva.value!),
        ],
      ),
    );
  }
}

class _TarjetaResumenVentas extends ConsumerWidget {
  const _TarjetaResumenVentas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenVentasProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: AppColors.azul, size: 24),
              SizedBox(width: 10),
              Expanded(child: Text('Resumen de ventas', style: AppTextStyles.subtitulo)),
            ],
          ),
          const SizedBox(height: 14),
          if (resumen.hasValue)
            _CifrasVentas(resumen: resumen.value!)
          else if (resumen.hasError)
            Row(
              children: [
                const Expanded(child: Text('No se pudo cargar el resumen de ventas.', style: AppTextStyles.nota)),
                TextButton(onPressed: () => ref.invalidate(resumenVentasProvider), child: const Text('Reintentar')),
              ],
            )
          else
            const SkeletonKpiResumen(),
        ],
      ),
    );
  }
}

class _CifrasVentas extends StatelessWidget {
  const _CifrasVentas({required this.resumen});

  final ResumenVentas resumen;

  @override
  Widget build(BuildContext context) {
    Widget kpiFinanciero(String etiqueta, String valor) => Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.panelSutil,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: AppTextStyles.nota),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: AppTextStyles.moneda.copyWith(fontSize: 22, color: AppColors.azul)),
              ),
            ],
          ),
        );

    Widget kpiOperativo(String etiqueta, String valor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: AppTextStyles.subtitulo.copyWith(
                fontSize: 17,
                color: AppColors.textoPrincipal,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
            Text(etiqueta, style: AppTextStyles.nota),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, caja) {
            final financieros = [
              ('Ingresos totales', Formatos.dinero(resumen.totalCentavos)),
              ('IVA recaudado', Formatos.dinero(resumen.ivaCentavos)),
            ];
            final operativos = [
              ('Reservas confirmadas', Formatos.entero(resumen.confirmadas)),
              ('Reservas canceladas', Formatos.entero(resumen.canceladas)),
              ('Asientos vendidos', Formatos.entero(resumen.asientosVendidos)),
            ];
            final dosCol = caja.maxWidth >= 420;
            final tresCol = caja.maxWidth >= 520;
            final anchoOp = tresCol
                ? (caja.maxWidth - 32) / 3
                : dosCol
                    ? (caja.maxWidth - 16) / 2
                    : caja.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dosCol)
                  Row(
                    children: [
                      Expanded(child: kpiFinanciero(financieros[0].$1, financieros[0].$2)),
                      const SizedBox(width: 12),
                      Expanded(child: kpiFinanciero(financieros[1].$1, financieros[1].$2)),
                    ],
                  )
                else ...[
                  kpiFinanciero(financieros[0].$1, financieros[0].$2),
                  const SizedBox(height: 10),
                  kpiFinanciero(financieros[1].$1, financieros[1].$2),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final c in operativos) SizedBox(width: anchoOp, child: kpiOperativo(c.$1, c.$2)),
                  ],
                ),
              ],
            );
          },
        ),
        if (resumen.top.isNotEmpty) ...[
          const Divider(height: 26, color: AppColors.divisor),
          const Text('Vuelos con más ingresos', style: AppTextStyles.etiqueta),
          const SizedBox(height: 8),
          for (final v in resumen.top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(v.codigo, style: AppTextStyles.codigo)),
                  Expanded(
                    child: Text(
                      '${v.ruta} · ${Formatos.entero(v.asientos)} ${v.asientos == 1 ? 'asiento' : 'asientos'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.nota.copyWith(fontFeatures: AppTextStyles.tabular),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Formatos.dinero(v.totalCentavos),
                    softWrap: false,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textoPrincipal,
                      fontFeatures: AppTextStyles.tabular,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _TarjetaAccionAdmin extends StatelessWidget {
  const _TarjetaAccionAdmin({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.accion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget accion;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.tarjeta,
        child: LayoutBuilder(
          builder: (context, caja) {
            final info = Row(
              children: [
                Icon(icono, color: AppColors.azul, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: AppTextStyles.subtitulo),
                      const SizedBox(height: 2),
                      Text(descripcion, style: AppTextStyles.cuerpo),
                    ],
                  ),
                ),
              ],
            );
            if (caja.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: accion),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                Flexible(child: Align(alignment: Alignment.centerRight, child: accion)),
              ],
            );
          },
        ),
      );
}

class _TarjetaVuelos extends StatelessWidget {
  const _TarjetaVuelos({required this.onCrear, required this.onGestionar});

  final VoidCallback onCrear;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) => _TarjetaAccionAdmin(
        icono: Icons.flight_takeoff,
        titulo: 'Vuelos',
        descripcion: 'Programe un vuelo nuevo, o edite y cancele los existentes.',
        accion: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onGestionar,
              icon: const Icon(Icons.list_alt),
              label: const Text('Gestionar'),
            ),
            FilledButton.icon(onPressed: onCrear, icon: const Icon(Icons.add), label: const Text('Crear')),
          ],
        ),
      );
}

class _TarjetaAviones extends StatelessWidget {
  const _TarjetaAviones({required this.onImportar});

  final VoidCallback onImportar;

  @override
  Widget build(BuildContext context) => _TarjetaAccionAdmin(
        icono: Icons.airplanemode_active,
        titulo: 'Aviones',
        descripcion: 'Cargue la flota desde un archivo CSV. Los asientos se generan solos.',
        accion: OutlinedButton.icon(
          onPressed: onImportar,
          icon: const Icon(Icons.upload_file),
          label: const Text('Importar'),
        ),
      );
}

class _SeccionIva extends ConsumerStatefulWidget {
  const _SeccionIva({required this.resumen});

  final ResumenIva resumen;

  @override
  ConsumerState<_SeccionIva> createState() => _SeccionIvaState();
}

class _SeccionIvaState extends ConsumerState<_SeccionIva> {
  final _formulario = GlobalKey<FormState>();
  final _porcentaje = TextEditingController();
  DateTime? _desde;
  bool _enviando = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _porcentaje.dispose();
    super.dispose();
  }

  Future<DateTime?> _elegirFecha() => elegirFechaDeTarifa(context, inicial: _desde);

  Future<void> _enviar() async {
    if (_ocupado || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final texto = _porcentaje.text.trim().replaceAll(',', '.');
    final desde = _desde!;
    _ocupado = true;
    setState(() => _error = null);

    final actual = widget.resumen.vigente?.porcentajeCorto;
    final nuevo = _porcentajeCorto(texto);
    final desdeTexto = Formatos.fecha(desde);
    final confirmado = await mostrarConfirmacionKuntur(
      context,
      titulo: '¿Cambiar el IVA?',
      mensaje: actual == null
          ? 'No hay una tarifa vigente. Se programará $nuevo % desde el $desdeTexto. Las reservas ya hechas no cambian.'
          : 'El IVA pasará de $actual a $nuevo % desde el $desdeTexto.\n\n'
              'Las reservas ya hechas conservan el IVA con el que se cobraron.',
      textoConfirmar: 'Sí, cambiar',
      textoCancelar: 'Cancelar',
      icono: Icons.percent,
    );
    if (!mounted) return;
    if (!confirmado) {
      _ocupado = false;
      return;
    }

    setState(() => _enviando = true);
    try {
      await ref.read(ivaControllerProvider.notifier).cambiar(porcentaje: texto, vigenteDesde: desde);
      if (!mounted) return;
      _porcentaje.clear();
      _ocupado = false;
      setState(() {
        _desde = null;
        _enviando = false;
      });
      _formulario.currentState?.reset();
      mostrarAviso(context, 'Tarifa de IVA registrada.');
    } catch (e) {
      _ocupado = false;
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vigente = widget.resumen.vigente;
    TarifaIva? programada;
    for (final t in widget.resumen.tarifas) {
      if (t.estado == EstadoTarifa.programada) {
        programada = t;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.percent, color: AppColors.azul, size: 26),
              SizedBox(width: 10),
              Text('IVA', style: AppTextStyles.subtitulo),
            ],
          ),
          const SizedBox(height: 14),
          if (vigente == null)
            const AvisoInline(
              tipo: TipoAviso.error,
              texto: 'No hay una tarifa de IVA vigente: nadie podrá reservar hasta que programe una.',
            )
          else ...[
            BloqueMetricaIsometrico(
              etiqueta: 'IVA vigente',
              valor: OdometroCinetico(
                texto: vigente.porcentajeCorto,
                estilo: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.azul,
                  height: 1,
                ),
              ),
              pie: Text(
                'vigente desde ${Formatos.fecha(vigente.vigenteDesde)}',
                style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.timeline, size: 16, color: AppColors.textoSuave),
                SizedBox(width: 8),
                Expanded(child: Text('Anterior · Ahora · Próxima', style: AppTextStyles.etiqueta)),
              ],
            ),
          ],
          if (programada != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoSuave, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Próxima tarifa programada: ${programada.porcentajeCorto} desde el ${Formatos.fecha(programada.vigenteDesde)}',
                      style: AppTextStyles.cuerpo.copyWith(color: AppColors.info, fontFeatures: AppTextStyles.tabular),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 32, color: AppColors.divisor),
          const Text('Programar un cambio', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
          const SizedBox(height: 4),
          const Text(
            'Aplica a las reservas nuevas desde la fecha elegida. Las ya hechas no cambian.',
            style: AppTextStyles.cuerpo,
          ),
          const SizedBox(height: 14),
          Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoTextoKuntur(
                  etiqueta: 'Nuevo porcentaje',
                  controlador: _porcentaje,
                  icono: Icons.percent,
                  mostrarLimpiar: true,
                  enabled: !_enviando,
                  hint: '15',
                  ayuda: 'De 0 a 100, hasta 2 decimales.',
                  tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  inputFormatters: ValidadoresVuelo.entradaPorcentaje,
                  validador: ValidadoresVuelo.porcentaje,
                ),
                const SizedBox(height: 14),
                CampoSelector<DateTime>(
                  etiqueta: 'Rige desde',
                  icono: Icons.calendar_month_outlined,
                  valor: _desde,
                  formato: Formatos.fecha,
                  elegir: _elegirFecha,
                  alElegir: (f) => setState(() => _desde = f),
                  validador: ValidadoresVuelo.inicioTarifa,
                  habilitado: !_enviando,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AvisoInline(texto: _error!),
                ],
                const SizedBox(height: 16),
                BotonDegradado(texto: 'Programar cambio', cargando: _enviando, onPressed: _enviar),
              ],
            ),
          ),
          const Divider(height: 32, color: AppColors.divisor),
          const Text('Historial', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
          const SizedBox(height: 8),
          if (widget.resumen.tarifas.isEmpty)
            const VacioVista(
              icono: Icons.percent,
              titulo: 'Sin historial de tarifas',
              mensaje: 'Cuando programe la primera tarifa aparecerá aquí.',
              elevada: false,
            )
          else
            ...widget.resumen.tarifas.map((t) => _FilaTarifa(tarifa: t)),
        ],
      ),
    );
  }
}

String _porcentajeCorto(String texto) {
  final partes = texto.trim().split('.');
  final decimales = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return decimales.isEmpty ? partes[0] : '${partes[0]}.$decimales';
}

class _FilaTarifa extends StatelessWidget {
  const _FilaTarifa({required this.tarifa});

  final TarifaIva tarifa;

  @override
  Widget build(BuildContext context) {
    final (texto, tipo) = switch (tarifa.estado) {
      EstadoTarifa.vigente => ('Vigente', TipoInsignia.exito),
      EstadoTarifa.programada => ('Programada', TipoInsignia.aviso),
      EstadoTarifa.anterior => ('Anterior', TipoInsignia.neutro),
    };
    final hasta = tarifa.vigenteHasta;
    final rango = hasta == null
        ? 'Desde ${Formatos.fecha(tarifa.vigenteDesde)}'
        : '${Formatos.fecha(tarifa.vigenteDesde)} → ${Formatos.fecha(hasta.subtract(const Duration(days: 1)))}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, caja) {
          final valor = ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              tarifa.porcentajeCorto,
              softWrap: false,
              style: AppTextStyles.subtitulo.copyWith(fontSize: 16, fontFeatures: AppTextStyles.tabular),
            ),
          );
          final fechas = Text(rango, style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular));
          final insignia = InsigniaEstado(texto: texto, tipo: tipo);
          if (caja.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [valor, const Spacer(), insignia]),
                const SizedBox(height: 2),
                fechas,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              valor,
              const SizedBox(width: 8),
              Expanded(child: fechas),
              const SizedBox(width: 8),
              insignia,
            ],
          );
        },
      ),
    );
  }
}
