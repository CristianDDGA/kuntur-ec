import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/gestion_vuelos_controller.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/control_paginas.dart';
import '../widgets/estado_vista.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';

/// Gestión de vuelos del administrador (V): todos los vuelos, también cancelados y ya partidos,
/// con las acciones Editar y Cancelar. Solo el administrador llega aquí (router + 403 del servidor).
class GestionVuelosPage extends ConsumerWidget {
  const GestionVuelosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroGestionProvider);
    final pagina = ref.watch(gestionVuelosProvider);

    return KunturScaffold(
      conAtras: true,
      seccion: Seccion.administracion,
      maxAncho: 900,
      onRefrescar: () => ref.read(gestionVuelosProvider.notifier).recargar(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Migas([Miga('Administración', ruta: AppRoutes.admin), Miga('Gestionar vuelos')]),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Gestionar vuelos', style: AppTextStyles.titulo)),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.nuevoVuelo),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              ),
            ],
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
            const CargandoDetalleVista()
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
            Text('${pagina.value!.total} vuelo(s)', style: AppTextStyles.nota),
            const SizedBox(height: 8),
            for (final v in pagina.value!.vuelos)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _TarjetaGestion(item: v)),
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
            : 'Vuelo ${item.vuelo.codigo} cancelado junto con $canceladas reserva(s).',
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
              Text(v.codigo, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.azul)),
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
              InsigniaEstado(texto: texto, tipo: tipo),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)} → ${Formatos.hora(v.horaLlegada)} · '
            '${Formatos.dinero(v.precioCentavos)}',
            style: AppTextStyles.cuerpo,
          ),
          const SizedBox(height: 2),
          Text(
            v.cancelado
                ? 'Capacidad ${v.capacidad} asientos'
                : '${v.asientosVendidos} de ${v.capacidad} asientos vendidos',
            style: AppTextStyles.nota,
          ),
          if (v.cancelado && v.motivoCancelacion != null) ...[
            const SizedBox(height: 8),
            AvisoInline(tipo: TipoAviso.info, texto: 'Motivo: ${v.motivoCancelacion}'),
          ],
          if (item.gestionable) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
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

/// Pide el motivo, advierte a cuántos pasajeros afecta y cancela. Devuelve cuántas reservas se
/// cancelaron, o `null` si el administrador se arrepintió.
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

  /// Versión con la que se confirma. Tras un 409 pasa a la `version_actual` del servidor, así el
  /// administrador revisa el aviso y vuelve a confirmar a sabiendas (nunca se reintenta solo).
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
      final actual = e.detalles['version_actual'];
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 409 && actual is int) {
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
    return AlertDialog(
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
                style: AppTextStyles.cuerpo,
              ),
              const SizedBox(height: 10),
              AvisoInline(
                tipo: v.tieneReservas ? TipoAviso.error : TipoAviso.info,
                texto: v.tieneReservas
                    ? 'Tiene ${v.asientosVendidos} asiento(s) vendido(s): todas sus reservas se cancelarán y '
                        'los pasajeros verán el motivo. No se puede deshacer.'
                    : 'Aún no tiene asientos vendidos. Dejará de aparecer en la búsqueda. No se puede deshacer.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _motivo,
                enabled: !cancelando,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: ValidadoresVuelo.motivoMax,
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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Cancelar vuelo'),
        ),
      ],
    );
  }
}
