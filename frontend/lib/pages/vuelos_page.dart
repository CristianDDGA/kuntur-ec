import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/vuelos_controller.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/barra_kuntur.dart';
import '../widgets/control_paginas.dart';
import '../widgets/campo_selector.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Pantalla principal (V): búsqueda y lista de vuelos. No llama a la API: delega en
/// [VuelosController] y en [FiltroVuelosController].
class VuelosPage extends ConsumerWidget {
  const VuelosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink(); // el router ya está redirigiendo al login

    final vuelos = ref.watch(vuelosControllerProvider);
    final filtro = ref.watch(filtroVuelosProvider);

    return Scaffold(
      appBar: BarraKuntur(
        acciones: [
          if (!usuario.esAdmin)
            IconButton(
              tooltip: 'Mis reservas',
              icon: const Icon(Icons.confirmation_number_outlined),
              onPressed: () => context.push(AppRoutes.reservas),
            ),
          if (usuario.esAdmin)
            IconButton(
              tooltip: 'Panel de administración',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push(AppRoutes.admin),
            ),
          IconButton(
            tooltip: 'Estado del servicio',
            icon: const Icon(Icons.cloud_done_outlined),
            onPressed: () => context.push(AppRoutes.estado),
          ),
        ],
      ),
      floatingActionButton: usuario.esAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.nuevoVuelo),
              backgroundColor: AppColors.amarillo,
              foregroundColor: AppColors.azulNoche,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo vuelo', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(vuelosControllerProvider.notifier).recargar(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                children: [
                  Text('Hola, ${usuario.nombre.split(' ').first}', style: AppTextStyles.titulo),
                  const SizedBox(height: 4),
                  const Text('¿A dónde viajamos? Busque su vuelo y reserve.', style: AppTextStyles.cuerpo),
                  const SizedBox(height: 16),
                  // La clave por filtro rehace los campos si el filtro cambia desde fuera.
                  _FormularioBusqueda(key: ValueKey((filtro.origen, filtro.destino, filtro.fecha)), inicial: filtro),
                  const SizedBox(height: 20),
                  ..._resultado(context, ref, vuelos, filtro),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resultado(BuildContext context, WidgetRef ref, AsyncValue<PaginaVuelos> vuelos, FiltroVuelos filtro) {
    if (vuelos.isLoading && !vuelos.hasValue) {
      return const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    }
    if (vuelos.hasError && !vuelos.hasValue) {
      return [
        AvisoInline(texto: mensajeDeError(vuelos.error!)),
        const SizedBox(height: 12),
        Align(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(vuelosControllerProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }
    final pagina = vuelos.value!;
    final lista = pagina.vuelos;
    final actualizando = vuelos.isLoading; // se muestra la página anterior mientras llega la nueva
    if (lista.isEmpty) {
      final fueraDeRango = pagina.total > 0; // pidió una página que ya no existe (salieron vuelos)
      return [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: AppDecorations.tarjeta,
          child: Column(
            children: [
              const Icon(Icons.flight_takeoff, size: 40, color: AppColors.textoSuave),
              const SizedBox(height: 10),
              Text(
                fueraDeRango
                    ? 'Esta página ya no tiene vuelos.'
                    : filtro.vacio
                        ? 'No hay vuelos programados.'
                        : 'No encontramos vuelos con esos datos.',
                style: AppTextStyles.subtitulo,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                fueraDeRango
                    ? 'Algunos vuelos ya partieron. Vuelva a la primera página.'
                    : filtro.vacio
                        ? 'Vuelva a consultar más tarde.'
                        : 'Pruebe con otra fecha o quite algún filtro.',
                style: AppTextStyles.cuerpo,
                textAlign: TextAlign.center,
              ),
              if (fueraDeRango) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => ref.read(filtroVuelosProvider.notifier).irAPagina(1),
                  child: const Text('Ir a la primera página'),
                ),
              ],
            ],
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          pagina.total == 1 ? '1 vuelo disponible' : '${pagina.total} vuelos disponibles',
          style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      Opacity(
        opacity: actualizando ? 0.5 : 1,
        child: Column(
          children: [
            for (final vuelo in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TarjetaVuelo(vuelo: vuelo, onTap: () => context.push(AppRoutes.vuelo(vuelo.id))),
              ),
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

  Future<DateTime?> _elegirFecha() {
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return showDatePicker(
      context: context,
      initialDate: _fecha ?? dia,
      firstDate: dia,
      lastDate: dia.add(const Duration(days: ValidadoresVuelo.diasMaxAdelante)),
      helpText: 'Fecha del vuelo',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayFiltros = !widget.inicial.vacio || _origen.text.isNotEmpty || _destino.text.isNotEmpty || _fecha != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.tarjeta,
      child: Form(
        key: _formulario,
        child: LayoutBuilder(
          builder: (context, caja) {
            final ancho = caja.maxWidth >= 560;
            final origen = TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _origen,
              inputFormatters: ValidadoresVuelo.entradaCiudad,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Origen', prefixIcon: Icon(Icons.flight_takeoff)),
              validator: ValidadoresVuelo.filtroCiudad,
            );
            final destino = TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _destino,
              inputFormatters: ValidadoresVuelo.entradaCiudad,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _buscar(),
              decoration: const InputDecoration(labelText: 'Destino', prefixIcon: Icon(Icons.flight_land)),
              validator: ValidadoresVuelo.filtroCiudad,
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
                if (ancho)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: origen),
                      const SizedBox(width: 12),
                      Expanded(child: destino),
                      const SizedBox(width: 12),
                      Expanded(child: fecha),
                    ],
                  )
                else ...[
                  origen,
                  const SizedBox(height: 12),
                  destino,
                  const SizedBox(height: 12),
                  fecha,
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (hayFiltros)
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
          },
        ),
      ),
    );
  }
}
