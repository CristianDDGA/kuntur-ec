import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/gestion_vuelos_controller.dart';
import '../models/fallo.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../widgets/aviso.dart';
import '../widgets/control_paginas.dart';
import '../widgets/estado_vista.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';

/// Gestión de vuelos del administrador (V): edición y cancelación con control optimista.
class GestionVuelosPage extends ConsumerWidget {
  const GestionVuelosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroGestionProvider);
    final pagina = ref.watch(gestionVuelosProvider);

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.administracion,
      maxAncho: 920,
      onRefrescar: () => ref.read(gestionVuelosProvider.notifier).recargar(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Migas([Miga('Administración', ruta: AppRoutes.admin), Miga('Gestionar vuelos')]),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, caja) {
              const titulo = Text('Gestionar vuelos', style: AppTextStyles.titulo);
              final boton = FilledButton.icon(
                onPressed: () => context.push(AppRoutes.nuevoVuelo),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              );
              if (caja.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titulo,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: boton),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: titulo),
                  const SizedBox(width: 12),
                  boton,
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Edite la programación o cancele un vuelo. Un vuelo cancelado no se borra: queda en el '
            'historial y sus pasajeros ven el motivo en su reserva.',
            style: AppTextStyles.cuerpo,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (texto, estado) in [
                ('Todos', null),
                ('Programados', EstadoVuelo.programado),
                ('Cancelados', EstadoVuelo.cancelado),
              ])
                ChoiceChip(
                  label: Text(texto),
                  selected: filtro.estado == estado,
                  onSelected: (_) => ref.read(filtroGestionProvider.notifier).estado(estado),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (pagina.isLoading && !pagina.hasValue)
            const CargandoVista(tarjetas: 3)
          else if (pagina.hasError && !pagina.hasValue)
            ErrorVista(
              mensaje: mensajeDeError(pagina.error!),
              onReintentar: () => ref.invalidate(gestionVuelosProvider),
            )
          else if (pagina.value!.vuelos.isEmpty)
            VacioVista(
              icono: Icons.flight,
              titulo: filtro.estado == EstadoVuelo.cancelado ? 'No hay vuelos cancelados' : 'No hay vuelos',
              mensaje: 'Los vuelos que cree aparecerán aquí.',
            )
          else ...[
            Text(
              pagina.value!.total == 1 ? '1 vuelo' : '${Formatos.entero(pagina.value!.total)} vuelos',
              style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTextStyles.tabular),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: pagina.isLoading ? 0.5 : 1,
              duration: AppMotion.opacidadDe(context),
              child: Column(
                children: [
                  for (final v in pagina.value!.vuelos)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: _TarjetaGestion(item: v)),
                ],
              ),
            ),
            ControlPaginas(
              pagina: pagina.value!.pagina,
              totalPaginas: pagina.value!.totalPaginas,
              ocupado: pagina.isLoading,
              onCambiar: (p) => ref.read(filtroGestionProvider.notifier).irA(p),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaGestion extends ConsumerWidget {
  const _TarjetaGestion({required this.item});

  final VueloGestionado item;

  Future<void> _cancelar(BuildContext context) async {
    final canceladas = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCancelar(vuelo: item.vuelo),
    );
    if (canceladas != null && context.mounted) {
      mostrarAviso(
        context,
        canceladas == 0
            ? 'Vuelo ${item.vuelo.codigo} cancelado.'
            : canceladas == 1
                ? 'Vuelo ${item.vuelo.codigo} cancelado junto con 1 reserva.'
                : 'Vuelo ${item.vuelo.codigo} cancelado junto con ${Formatos.entero(canceladas)} reservas.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = item.vuelo;
    final (texto, tipo) = v.cancelado
        ? ('Cancelado', TipoInsignia.error)
        : item.yaPartio
            ? ('Partió', TipoInsignia.neutro)
            : ('Programado', TipoInsignia.exito);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(v.codigo, style: AppTextStyles.codigo),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${v.origen} → ${v.destino}',
                  style: AppTextStyles.subtitulo.copyWith(
                    fontSize: 16,
                    decoration: v.cancelado ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InsigniaEstado(texto: texto, tipo: tipo),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)} → ${Formatos.hora(v.horaLlegada)} · '
            '${Formatos.dinero(v.precioCentavos)}',
            style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular),
          ),
          const SizedBox(height: 2),
          Text(
            v.cancelado
                ? 'Capacidad ${Formatos.entero(v.capacidad)} ${v.capacidad == 1 ? 'asiento' : 'asientos'}'
                : '${Formatos.entero(v.asientosVendidos)} de ${Formatos.entero(v.capacidad)} asientos vendidos',
            style: AppTextStyles.nota.copyWith(fontFeatures: AppTextStyles.tabular),
          ),
          if (v.cancelado && v.motivoCancelacion != null) ...[
            const SizedBox(height: 8),
            AvisoInline(tipo: TipoAviso.info, texto: 'Motivo: ${v.motivoCancelacion}'),
          ],
          if (item.gestionable) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.editarVuelo(v.id)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: () => _cancelar(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar vuelo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogoCancelar extends ConsumerStatefulWidget {
  const _DialogoCancelar({required this.vuelo});

  final Vuelo vuelo;

  @override
  ConsumerState<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends ConsumerState<_DialogoCancelar> {
  final _formulario = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  String? _error;

  late int _version = widget.vuelo.version;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      final canceladas = await ref
          .read(cancelarVueloProvider.notifier)
          .cancelar(widget.vuelo, ValidadoresVuelo.normalizarTexto(_motivo.text), version: _version);
      if (canceladas != null && mounted) Navigator.of(context).pop(canceladas);
    } on ServerFailure catch (e) {
      final actual = e.versionActual;
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 409 && actual != null) {
          _version = actual;
          _error = 'Otro administrador cambió este vuelo mientras usted lo revisaba. El listado ya muestra '
              'sus datos actuales; si aún quiere cancelarlo, pulse «Cancelar vuelo» otra vez.';
        } else {
          _error = mensajeDeError(e);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelando = ref.watch(cancelarVueloProvider);
    final v = widget.vuelo;
    final vendidosTexto = v.asientosVendidos == 1
        ? '1 asiento vendido'
        : '${Formatos.entero(v.asientosVendidos)} asientos vendidos';

    return AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 32),
      title: Text('¿Cancelar el vuelo ${v.codigo}?'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${v.origen} → ${v.destino} · ${Formatos.fecha(v.fecha)} ${Formatos.hora(v.horaSalida)}',
                style: AppTextStyles.cuerpo.copyWith(fontFeatures: AppTextStyles.tabular),
              ),
              const SizedBox(height: 10),
              AvisoInline(
                tipo: v.tieneReservas ? TipoAviso.error : TipoAviso.info,
                texto: v.tieneReservas
                    ? 'Tiene $vendidosTexto: todas sus reservas se cancelarán y los pasajeros verán el motivo. No se puede deshacer.'
                    : 'Aún no tiene asientos vendidos. Dejará de aparecer en la búsqueda. No se puede deshacer.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _motivo,
                enabled: !cancelando,
                autofocus: true,
                minLines: 2,
                maxLines: 3,
                maxLength: ValidadoresVuelo.motivoMax,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirmar(),
                inputFormatters: ValidadoresVuelo.entradaMotivo,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: ValidadoresVuelo.motivoCancelacion,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la cancelación',
                  hintText: 'Ej.: cierre del aeropuerto por mal clima',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                AvisoInline(texto: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: cancelando ? null : () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: cancelando ? null : _confirmar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: cancelando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Cancelar vuelo'),
        ),
      ],
    );
  }
}
