import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/vuelos_controller.dart';
import '../models/fallo.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../widgets/campo_selector.dart';
import '../widgets/campo_texto_kuntur.dart';
import '../widgets/control_paginas.dart';
import '../widgets/estado_vista.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/rejilla_adaptable.dart';
import '../widgets/selectores_fecha_hora.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Pantalla principal operativa (V): búsqueda y catálogo de vuelos.
/// Delega toda lógica en [VuelosController] y [FiltroVuelosController].
class VuelosPage extends ConsumerWidget {
  const VuelosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink();

    final vuelos = ref.watch(vuelosControllerProvider);
    final filtro = ref.watch(filtroVuelosProvider);

    return KunturScaffold(
      seccion: Seccion.vuelos,
      onRefrescar: () => ref.read(vuelosControllerProvider.notifier).recargar(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          LayoutBuilder(
            builder: (context, caja) {
              final saludo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${usuario.nombre.split(' ').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titulo,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usuario.esAdmin
                        ? 'Catálogo operativo de vuelos del sistema.'
                        : '¿A dónde viajamos? Busque su vuelo y reserve.',
                    style: AppTextStyles.cuerpo,
                  ),
                ],
              );
              if (!usuario.esAdmin) return saludo;
              final boton = FilledButton.icon(
                onPressed: () => context.push(AppRoutes.nuevoVuelo),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo vuelo'),
              );
              if (caja.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    saludo,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: boton),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: saludo),
                  const SizedBox(width: 12),
                  boton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _FormularioBusqueda(key: ValueKey((filtro.origen, filtro.destino, filtro.fecha)), inicial: filtro),
          const SizedBox(height: 20),
          ..._resultado(context, ref, vuelos, filtro, esAdmin: usuario.esAdmin),
        ],
      ),
    );
  }

  List<Widget> _resultado(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PaginaVuelos> vuelos,
    FiltroVuelos filtro, {
    bool esAdmin = false,
  }) {
    if (vuelos.isLoading && !vuelos.hasValue) {
      return const [CargandoVista(tarjetas: 3)];
    }
    if (vuelos.hasError && !vuelos.hasValue) {
      return [
        ErrorVista(
          mensaje: mensajeDeError(vuelos.error!),
          onReintentar: () => ref.invalidate(vuelosControllerProvider),
        ),
      ];
    }
    final pagina = vuelos.value!;
    final lista = pagina.vuelos;
    final actualizando = vuelos.isLoading;
    if (lista.isEmpty) {
      final fueraDeRango = pagina.total > 0;
      final catalogoVacioAdmin = esAdmin && !fueraDeRango && filtro.vacio;
      return [
        VacioVista(
          icono: Icons.flight_takeoff,
          titulo: catalogoVacioAdmin
              ? 'Aún no hay vuelos.'
              : fueraDeRango
                  ? 'Esta página ya no tiene vuelos.'
                  : filtro.vacio
                      ? 'No hay vuelos programados.'
                      : 'No encontramos vuelos con esos datos.',
          mensaje: catalogoVacioAdmin
              ? 'Programe el primer vuelo del catálogo.'
              : fueraDeRango
                  ? 'Algunos vuelos ya partieron. Vuelva a la primera página.'
                  : filtro.vacio
                      ? 'Vuelva a consultar más tarde.'
                      : 'Pruebe con otra fecha o quite algún filtro.',
          textoAccion: fueraDeRango
              ? 'Ir a la primera página'
              : catalogoVacioAdmin
                  ? 'Programar el primero'
                  : null,
          onAccion: fueraDeRango
              ? () => ref.read(filtroVuelosProvider.notifier).irAPagina(1)
              : catalogoVacioAdmin
                  ? () => context.push(AppRoutes.nuevoVuelo)
                  : null,
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          pagina.total == 1 ? '1 vuelo disponible' : '${Formatos.entero(pagina.total)} vuelos disponibles',
          style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTextStyles.tabular),
        ),
      ),
      AnimatedOpacity(
        opacity: actualizando ? 0.5 : 1,
        duration: AppMotion.opacidadDe(context),
        child: RejillaAdaptable(
          hijos: [
            for (final vuelo in lista)
              TarjetaVuelo(vuelo: vuelo, onTap: () => context.push(AppRoutes.vuelo(vuelo.id))),
          ],
        ),
      ),
      ControlPaginas(
        pagina: pagina.pagina,
        totalPaginas: pagina.totalPaginas,
        ocupado: actualizando,
        onCambiar: (n) => ref.read(filtroVuelosProvider.notifier).irAPagina(n),
      ),
    ];
  }
}

class _FormularioBusqueda extends ConsumerStatefulWidget {
  const _FormularioBusqueda({super.key, required this.inicial});

  final FiltroVuelos inicial;

  @override
  ConsumerState<_FormularioBusqueda> createState() => _FormularioBusquedaState();
}

class _FormularioBusquedaState extends ConsumerState<_FormularioBusqueda> {
  final _formulario = GlobalKey<FormState>();
  late final _origen = TextEditingController(text: widget.inicial.origen);
  late final _destino = TextEditingController(text: widget.inicial.destino);
  late DateTime? _fecha = widget.inicial.fecha;
  bool _abierto = true;

  @override
  void dispose() {
    _origen.dispose();
    _destino.dispose();
    super.dispose();
  }

  void _buscar() {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(filtroVuelosProvider.notifier).aplicar(FiltroVuelos(
          origen: ValidadoresVuelo.normalizarTexto(_origen.text),
          destino: ValidadoresVuelo.normalizarTexto(_destino.text),
          fecha: _fecha,
        ));
  }

  void _limpiar() {
    _origen.clear();
    _destino.clear();
    setState(() => _fecha = null);
    ref.read(filtroVuelosProvider.notifier).limpiar();
  }

  void _intercambiar() {
    final origen = _origen.text;
    _origen.text = _destino.text;
    _destino.text = origen;
  }

  Future<DateTime?> _elegirFecha() => elegirFechaDeVuelo(context, inicial: _fecha);

  void _quitarFiltro({bool origen = false, bool destino = false, bool fecha = false}) {
    if (origen) _origen.clear();
    if (destino) _destino.clear();
    if (fecha) setState(() => _fecha = null);
    ref.read(filtroVuelosProvider.notifier).aplicar(FiltroVuelos(
          origen: origen ? '' : ValidadoresVuelo.normalizarTexto(_origen.text),
          destino: destino ? '' : ValidadoresVuelo.normalizarTexto(_destino.text),
          fecha: fecha ? null : _fecha,
        ));
  }

  Widget _chipFiltro(String texto, {required String tooltip, required VoidCallback onDeleted}) => InputChip(
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(texto, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        onDeleted: onDeleted,
        deleteButtonTooltipMessage: tooltip,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: AppDecorations.tarjeta,
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 18, color: AppColors.textoSuave),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Filtros de búsqueda', style: AppTextStyles.etiqueta),
                ),
                IconButton(
                  tooltip: _abierto ? 'Ocultar filtros' : 'Mostrar filtros',
                  onPressed: () => setState(() => _abierto = !_abierto),
                  icon: AnimatedRotation(
                    turns: _abierto ? 0.5 : 0,
                    duration: AppMotion.rapidaDe(context),
                    curve: AppMotion.curvaSalidaFuerte,
                    child: const Icon(Icons.expand_more),
                  ),
                ),
              ],
            ),
            ContenedorLiquidMorph(
              expandido: _abierto,
              radio: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: _espacioEtiqueta),
                  _campos(context),
                  if (_hayFiltros) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (widget.inicial.origen.isNotEmpty)
                          _chipFiltro(
                            'Origen: ${widget.inicial.origen}',
                            tooltip: 'Quitar filtro de origen',
                            onDeleted: () => _quitarFiltro(origen: true),
                          ),
                        if (widget.inicial.destino.isNotEmpty)
                          _chipFiltro(
                            'Destino: ${widget.inicial.destino}',
                            tooltip: 'Quitar filtro de destino',
                            onDeleted: () => _quitarFiltro(destino: true),
                          ),
                        if (widget.inicial.fecha != null)
                          _chipFiltro(
                            'Fecha: ${Formatos.fecha(widget.inicial.fecha!)}',
                            tooltip: 'Quitar filtro de fecha',
                            onDeleted: () => _quitarFiltro(fecha: true),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _espacioEtiqueta = 8.0;

  Widget _campos(BuildContext context) {
    final origen = CampoTextoKuntur(
      etiqueta: 'Origen',
      controlador: _origen,
      icono: Icons.flight_takeoff,
      mostrarLimpiar: true,
      validador: ValidadoresVuelo.filtroCiudad,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
    );
    final destino = CampoTextoKuntur(
      etiqueta: 'Destino',
      controlador: _destino,
      icono: Icons.flight_land,
      mostrarLimpiar: true,
      validador: ValidadoresVuelo.filtroCiudad,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.search,
      onEnviado: (_) => _buscar(),
    );
    final fecha = CampoSelector<DateTime>(
      etiqueta: 'Fecha (opcional)',
      icono: Icons.calendar_month_outlined,
      valor: _fecha,
      formato: Formatos.fecha,
      elegir: _elegirFecha,
      alElegir: (f) => setState(() => _fecha = f),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, caja) {
            final apilar = caja.maxWidth < 540;
            if (apilar) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  origen,
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Intercambiar origen y destino',
                      onPressed: _intercambiar,
                      icon: const Icon(Icons.swap_vert),
                    ),
                  ),
                  const SizedBox(height: 6),
                  destino,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: origen),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    tooltip: 'Intercambiar origen y destino',
                    onPressed: _intercambiar,
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
                Expanded(child: destino),
              ],
            );
          },
        ),
        // Reserva altura mínima fija para no desplazar los botones al escribir (sin recortar rutas largas).
        ListenableBuilder(
          listenable: Listenable.merge([_origen, _destino]),
          builder: (context, _) {
            final desde = _origen.text.trim();
            final hacia = _destino.text.trim();
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: desde.isEmpty || hacia.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextoRutaCinetica(
                          origen: desde,
                          destino: hacia,
                          maxLines: 2,
                          estilo: AppTextStyles.cuerpo.copyWith(fontWeight: FontWeight.w800, color: AppColors.azul),
                        ),
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 8),
        fecha,
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (_hayFiltros)
              TextButton.icon(
                onPressed: _limpiar,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Limpiar'),
              ),
            FilledButton.icon(
              onPressed: _buscar,
              icon: const Icon(Icons.search),
              label: const Text('Buscar vuelos'),
            ),
          ],
        ),
      ],
    );
  }

  bool get _hayFiltros =>
      !widget.inicial.vacio || _origen.text.isNotEmpty || _destino.text.isNotEmpty || _fecha != null;
}
