import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/aviones_controller.dart';
import '../controllers/crear_vuelo_controller.dart';
import '../controllers/gestion_vuelos_controller.dart';
import '../controllers/vuelo_detalle_controller.dart';
import '../models/avion.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';
import '../widgets/campo_texto_kuntur.dart';
import '../widgets/estado_vista.dart';
import '../widgets/fila_detalle.dart';
import '../widgets/hoja_confirmacion.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/liquid_morph.dart';
import '../widgets/migas.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/selectores_fecha_hora.dart';

/// Ciudades frecuentes del Ecuador como sugerencia rápida (nunca impiden escribir otra).
const List<String> _ciudadesFrecuentes = [
  'Quito',
  'Guayaquil',
  'Cuenca',
  'Loja',
  'Manta',
  'Ambato',
  'Esmeraldas',
  'Ibarra',
];

/// Formulario "Nuevo vuelo" y "Editar vuelo" (V): las mismas reglas en los dos casos. Solo el
/// administrador llega aquí (lo garantiza el router y, en última instancia, el servidor con 403).
class CrearVueloPage extends ConsumerStatefulWidget {
  const CrearVueloPage({super.key, this.vueloId});

  /// `null` = crear un vuelo nuevo; si no, se edita ese vuelo.
  final int? vueloId;

  @override
  ConsumerState<CrearVueloPage> createState() => _CrearVueloPageState();
}

class _CrearVueloPageState extends ConsumerState<CrearVueloPage> {
  final _formulario = GlobalKey<FormState>();
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _precio = TextEditingController();
  Avion? _avion;
  DateTime? _fecha;
  Duration? _salida;
  Duration? _llegada;

  /// Vuelo que se está editando, tal como llegó del servidor (null al crear o mientras carga).
  Vuelo? _original;

  bool get _editando => widget.vueloId != null;

  /// Con asientos vendidos no se pueden cambiar la ruta ni el avión (el servidor también lo impide).
  bool get _rutaBloqueada => _original?.tieneReservas ?? false;

  /// Llena el formulario con el vuelo a editar (una sola vez, o de nuevo al pedir "Recargar").
  void _cargar(Vuelo vuelo) {
    _original = vuelo;
    _origen.text = vuelo.origen;
    _destino.text = vuelo.destino;
    _precio.text = Formatos.dinero(vuelo.precioCentavos).replaceAll(RegExp(r'[^0-9.]'), '');
    _fecha = vuelo.fecha;
    _salida = vuelo.horaSalida;
    _llegada = vuelo.horaLlegada;
    _avion = null; // se elige en el selector cuando llegue la lista de aviones
  }

  /// Vuelve a leer el vuelo (p. ej. si otro administrador lo cambió: 409).
  void _recargar() {
    ref.invalidate(vueloDetalleControllerProvider(widget.vueloId!));
    ref.invalidate(editarVueloControllerProvider);
    setState(() => _original = null);
  }

  @override
  void initState() {
    super.initState();
    // PopScope necesita saber si hay datos escritos para preguntar antes de salir.
    for (final c in [_origen, _destino, _precio]) {
      c.addListener(_alCambiar);
    }
    final id = widget.vueloId;
    if (id != null) {
      // Cuando llega el vuelo (o llega de nuevo tras "Recargar") se llena el formulario.
      ref.listenManual(vueloDetalleControllerProvider(id), (_, estado) {
        final vuelo = estado.value;
        if (vuelo == null || _original != null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _original == null) setState(() => _cargar(vuelo));
        });
      }, fireImmediately: true);
    }
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_origen, _destino, _precio]) {
      c.removeListener(_alCambiar);
      c.dispose();
    }
    super.dispose();
  }

  /// Hay algo escrito o elegido (o cambiado, al editar): salir sin guardar perdería el formulario.
  bool get _sucio {
    final o = _original;
    if (_editando) {
      if (o == null) return false;
      return ValidadoresVuelo.normalizarTexto(_origen.text) != o.origen ||
          ValidadoresVuelo.normalizarTexto(_destino.text) != o.destino ||
          Formatos.centavosDe(ValidadoresVuelo.normalizarPrecio(_precio.text)) != o.precioCentavos ||
          _fecha != o.fecha ||
          _salida != o.horaSalida ||
          _llegada != o.horaLlegada ||
          (_avion != null && _avion!.id != o.avionId);
    }
    return [_origen, _destino, _precio].any((c) => c.text.trim().isNotEmpty) ||
        _avion != null ||
        _fecha != null ||
        _salida != null ||
        _llegada != null;
  }

  Future<void> _enviar() async {
    if (_editando) return _guardarCambios();
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final vuelo = await ref.read(crearVueloControllerProvider.notifier).crear(NuevoVuelo(
          origen: ValidadoresVuelo.normalizarTexto(_origen.text),
          destino: ValidadoresVuelo.normalizarTexto(_destino.text),
          fecha: _fecha!,
          horaSalida: _salida!,
          horaLlegada: _llegada!,
          precio: ValidadoresVuelo.normalizarPrecio(_precio.text),
          avionId: _avion!.id,
        ));
    if (vuelo != null && mounted) {
      mostrarAviso(context, 'Vuelo ${vuelo.codigo} creado correctamente.');
      context.pushReplacement(AppRoutes.vuelo(vuelo.id));
    }
  }

  Future<void> _guardarCambios() async {
    final original = _original;
    if (original == null || ref.read(editarVueloControllerProvider).isLoading) return;
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (!_sucio) {
      mostrarAviso(context, 'No hay cambios que guardar.');
      return;
    }
    // Cambiar el horario de un vuelo con pasajeros les afecta: se confirma antes.
    final cambiaHorario =
        _fecha != original.fecha || _salida != original.horaSalida || _llegada != original.horaLlegada;
    if (original.tieneReservas && cambiaHorario) {
      final seguir = await mostrarConfirmacionKuntur(
        context,
        titulo: '¿Cambiar el horario?',
        mensaje: 'El vuelo ${original.codigo} tiene ${original.asientosVendidos} asiento(s) vendido(s). '
            'Los pasajeros verán el nuevo horario en su reserva: '
            '${Formatos.fecha(_fecha!)}, ${Formatos.hora(_salida!)} → ${Formatos.hora(_llegada!)}.',
        textoConfirmar: 'Sí, cambiar',
        textoCancelar: 'Revisar',
        icono: Icons.schedule,
      );
      if (!seguir || !mounted) return;
    }
    final avionNuevo = _avion != null && _avion!.id != original.avionId ? _avion!.id : null;
    final vuelo = await ref.read(editarVueloControllerProvider.notifier).editar(
          original.id,
          EdicionVuelo(
            origen: ValidadoresVuelo.normalizarTexto(_origen.text),
            destino: ValidadoresVuelo.normalizarTexto(_destino.text),
            fecha: _fecha!,
            horaSalida: _salida!,
            horaLlegada: _llegada!,
            precio: ValidadoresVuelo.normalizarPrecio(_precio.text),
            avionId: avionNuevo,
            version: original.version,
          ),
        );
    if (vuelo != null && mounted) {
      setState(() => _original = vuelo); // ya no hay cambios pendientes: se puede salir sin preguntar
      mostrarAviso(context, 'Vuelo ${vuelo.codigo} actualizado correctamente.');
      context.pop();
    }
  }

  Future<DateTime?> _elegirFecha() => elegirFechaDeVuelo(context, inicial: _fecha);

  /// Si el vuelo es hoy se propone la próxima hora completa; si no, las 08:00.
  Duration _salidaSugerida() {
    final ahora = DateTime.now();
    final f = _fecha;
    final hoy = f != null && f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
    if (!hoy) return const Duration(hours: 8);
    return ahora.hour < 23 ? Duration(hours: ahora.hour + 1) : const Duration(hours: 23, minutes: 59);
  }

  /// Selector de hora en formato 24 h. Si aún no hay hora, propone [sugerida].
  Future<Duration?> _elegirHora(Duration? actual, String ayuda, {Duration sugerida = const Duration(hours: 8)}) async {
    final inicial = actual ?? sugerida;
    final hora = await elegirHoraKuntur(
      context,
      inicial: TimeOfDay(hour: inicial.inHours % 24, minute: inicial.inMinutes % 60),
      ayuda: ayuda,
      usar24Horas: true,
    );
    return hora == null ? null : Duration(hours: hora.hour, minutes: hora.minute);
  }

  /// Toca una ciudad sugerida: llena el primer campo vacío (origen y luego destino).
  /// Si ambos ya tienen texto no pisa nada.
  void _sugerirCiudad(String ciudad) {
    if (_origen.text.trim().isEmpty) {
      setState(() => _origen.text = ciudad);
    } else if (_destino.text.trim().isEmpty) {
      setState(() => _destino.text = ciudad);
    }
  }

  /// Duración entre salida y llegada (si la llegada cruza la medianoche, suma un día).
  String? get _duracionTexto {
    final salida = _salida;
    final llegada = _llegada;
    if (salida == null || llegada == null) return null;
    var minutos = llegada.inMinutes - salida.inMinutes;
    if (minutos < 0) minutos += 24 * 60;
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '$horas h' : '$horas h $resto min';
  }

  /// Filas de la cabina **3 + pasillo + 3** del avión elegido (6 asientos por fila visual), o `null`
  /// mientras no se haya elegido avión.
  int? get _filasCabina {
    final capacidad = _avion?.capacidad ?? _original?.capacidad;
    return capacidad == null ? null : (capacidad / 6).ceil();
  }

  /// Una ciudad frecuente resalta cuando ya es el origen o el destino escrito.
  bool _ciudadElegida(String ciudad) {
    final nombre = ciudad.toLowerCase();
    return _origen.text.trim().toLowerCase() == nombre || _destino.text.trim().toLowerCase() == nombre;
  }

  /// Tarjeta de vista previa en vivo: ruta cinética, duración y cabina 3+3.
  Widget _vistaPrevia() {
    final duracion = _duracionTexto;
    final filas = _filasCabina;
    return MarcoIsometrico25D(
      radio: 16,
      color: AppColors.infoSuave,
      relleno: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flight_takeoff, size: 18, color: AppColors.azul),
              SizedBox(width: 8),
              Expanded(child: Text('Vista previa del vuelo', style: AppTextStyles.etiqueta)),
            ],
          ),
          const SizedBox(height: 8),
          TextoRutaCinetica(
            origen: _origen.text,
            destino: _destino.text,
            estilo: AppTextStyles.subtitulo,
          ),
          if (duracion != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.textoSecundario),
                const SizedBox(width: 6),
                Semantics(
                  label: 'Duración estimada',
                  child: Text(duracion, style: AppTextStyles.cuerpo),
                ),
              ],
            ),
          ],
          if (filas != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cabina 3+3 · $filas filas',
              style: AppTextStyles.etiqueta.copyWith(color: AppColors.azul),
            ),
          ],
        ],
      ),
    );
  }

  /// Chip de ciudad frecuente con respuesta líquida cuando ya está elegida.
  Widget _chipCiudad(String ciudad) {
    final activa = _ciudadElegida(ciudad);
    return CapsulaLiquidMorph(
      activa: activa,
      radio: 20,
      colorActiva: AppColors.amarillo.withValues(alpha: 0.35),
      child: ActionChip(
        label: Text(ciudad),
        onPressed: () => _sugerirCiudad(ciudad),
        backgroundColor: activa ? Colors.transparent : AppColors.infoSuave,
        side: BorderSide.none,
      ),
    );
  }

  Future<bool> _confirmarSalidaSinGuardar() => mostrarConfirmacionKuntur(
        context,
        titulo: _editando ? '¿Salir sin guardar los cambios?' : '¿Salir sin crear el vuelo?',
        mensaje: _editando ? 'El vuelo quedará como estaba.' : 'Los datos que escribió se perderán.',
        textoConfirmar: 'Salir',
        textoCancelar: 'Seguir aquí',
        estilo: EstiloConfirmacion.destructiva,
        icono: Icons.flight_takeoff,
      );

  Future<void> _confirmarSalida() async {
    final salir = await _confirmarSalidaSinGuardar();
    if (salir && mounted) context.pop();
  }

  /// El logo de la barra también navega: con datos escritos se confirma antes.
  Future<void> _salirAInicio() async {
    if (!_sucio || await _confirmarSalidaSinGuardar()) {
      if (mounted) context.go(AppRoutes.vuelos);
    }
  }

  /// Selector del avión: la capacidad del vuelo es la del avión (se cargan por CSV).
  Widget _campoAvion(AsyncValue<List<Avion>> aviones) {
    return aviones.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Avión', prefixIcon: Icon(Icons.airplanemode_active)),
        child: Text('Cargando aviones…', style: AppTextStyles.cuerpo),
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvisoInline(texto: mensajeDeError(e)),
          TextButton(onPressed: () => ref.invalidate(avionesProvider), child: const Text('Reintentar')),
        ],
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AvisoInline(
                tipo: TipoAviso.info,
                texto: 'Aún no hay aviones. Importe un CSV para poder crear vuelos.',
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.importarAviones),
                child: const Text('Importar aviones'),
              ),
            ],
          );
        }
        // Al recargar la lista se conserva el avión elegido; al editar se parte del avión actual.
        final elegidoId = _avion?.id ?? _original?.avionId;
        // Al editar, el avión solo se exige si se puede cambiar: con asientos vendidos el selector
        // está bloqueado y el servidor conserva el actual; un vuelo antiguo sin avión puede seguir sin él.
        final obligatorio = !_editando || (_original?.avionId != null && !_rutaBloqueada);
        return DropdownButtonFormField<Avion>(
          key: ValueKey(('avion', _original?.version)),
          initialValue: lista.where((a) => a.id == elegidoId).firstOrNull,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Avión',
            prefixIcon: const Icon(Icons.airplanemode_active),
            helperText: _rutaBloqueada
                ? 'No se puede cambiar: el vuelo ya tiene asientos vendidos.'
                : 'Define la capacidad y el mapa de asientos.',
          ),
          items: [
            for (final a in lista) DropdownMenuItem(value: a, child: Text(a.etiqueta, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _rutaBloqueada ? null : (a) => setState(() => _avion = a),
          validator: (a) => a == null && obligatorio ? 'Elija el avión del vuelo.' : null,
        );
      },
    );
  }

  /// El servidor decide con la hora de Ecuador; aquí solo se evita mostrar un formulario inútil.
  static bool _yaPartio(Vuelo v) => !v.fecha.add(v.horaSalida).isAfter(DateTime.now());

  Widget _marcoEdicion(Widget contenido) => KunturScaffold(
        conAtras: true,
        seccion: Seccion.administracion,
        maxAncho: 800,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Migas([
              Miga('Administración', ruta: AppRoutes.admin),
              Miga('Gestionar vuelos', ruta: AppRoutes.gestionVuelos),
              Miga('Editar vuelo'),
            ]),
            const SizedBox(height: 12),
            contenido,
          ],
        ),
      );

  Widget _cargandoEdicion() {
    final vuelo = ref.watch(vueloDetalleControllerProvider(widget.vueloId!));
    if (vuelo.hasError && !vuelo.isLoading) {
      return _marcoEdicion(ErrorVista(mensaje: mensajeDeError(vuelo.error!), onReintentar: _recargar));
    }
    return _marcoEdicion(const CargandoDetalleVista());
  }

  Widget _noEditable(Vuelo vuelo) => _marcoEdicion(
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AppDecorations.tarjeta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vuelo ${vuelo.codigo}', style: AppTextStyles.titulo),
              const SizedBox(height: 12),
              AvisoInline(
                tipo: TipoAviso.info,
                texto: vuelo.cancelado
                    ? 'Este vuelo fue cancelado (${vuelo.motivoCancelacion ?? 'sin motivo'}). Ya no se puede editar.'
                    : 'Este vuelo ya partió. Ya no se puede editar.',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.gestionVuelos),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Object?> estado =
        _editando ? ref.watch(editarVueloControllerProvider) : ref.watch(crearVueloControllerProvider);
    final enviando = estado.isLoading;
    final fallo = estado.hasError && !enviando ? estado.error : null;
    final error = fallo == null ? null : mensajeDeError(fallo);
    // 409 al editar: otro administrador cambió el vuelo mientras tanto; se ofrece recargarlo.
    final desactualizado = _editando && fallo is ServerFailure && fallo.statusCode == 409;

    if (_editando && _original == null) return _cargandoEdicion();
    final original = _original;
    if (original != null && (original.cancelado || _yaPartio(original))) return _noEditable(original);

    final origen = CampoTextoKuntur(
      etiqueta: 'Origen',
      controlador: _origen,
      icono: Icons.flight_takeoff,
      enabled: !_rutaBloqueada,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
      validador: (v) => ValidadoresVuelo.ciudad(v, nombre: 'El origen'),
    );
    final destino = CampoTextoKuntur(
      etiqueta: 'Destino',
      controlador: _destino,
      icono: Icons.flight_land,
      enabled: !_rutaBloqueada,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
      validador: (v) => ValidadoresVuelo.destinoDistinto(v, _origen.text),
    );
    final precio = CampoTextoKuntur(
      etiqueta: 'Precio por persona (USD)',
      controlador: _precio,
      icono: Icons.attach_money,
      mostrarLimpiar: true,
      hint: '75.50',
      ayuda: 'Máximo \$10000, hasta 2 decimales.',
      tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: ValidadoresVuelo.entradaPrecio,
      validador: ValidadoresVuelo.precio,
    );
    final avion = _campoAvion(ref.watch(avionesProvider));
    final fecha = CampoSelector<DateTime>(
      etiqueta: 'Fecha',
      icono: Icons.calendar_month_outlined,
      valor: _fecha,
      formato: Formatos.fecha,
      elegir: _elegirFecha,
      alElegir: (f) => setState(() => _fecha = f),
      validador: ValidadoresVuelo.fecha,
      errorEnVivo: _fecha == null ? null : ValidadoresVuelo.fecha(_fecha),
    );
    final salida = CampoSelector<Duration>(
      etiqueta: 'Hora de salida',
      icono: Icons.schedule,
      valor: _salida,
      formato: Formatos.hora,
      elegir: () => _elegirHora(_salida, 'Hora de salida', sugerida: _salidaSugerida()),
      alElegir: (h) => setState(() => _salida = h),
      validador: (v) => ValidadoresVuelo.salida(v, _fecha),
      // Hoy no se puede elegir una hora que ya pasó: se avisa apenas se elige, no al enviar.
      errorEnVivo: _salida == null ? null : ValidadoresVuelo.salida(_salida, _fecha),
    );
    final llegada = CampoSelector<Duration>(
      etiqueta: 'Hora de llegada',
      icono: Icons.schedule,
      valor: _llegada,
      formato: Formatos.hora,
      elegir: () => _elegirHora(
        _llegada,
        'Hora de llegada',
        sugerida: (_salida ?? const Duration(hours: 7)) + const Duration(hours: 1), // propone 1 h después de la salida
      ),
      alElegir: (h) => setState(() => _llegada = h),
      validador: (v) => ValidadoresVuelo.llegada(v, _salida),
      errorEnVivo: _llegada == null ? null : ValidadoresVuelo.llegada(_llegada, _salida),
    );

    return PopScope(
      canPop: !_sucio,
      onPopInvokedWithResult: (salio, _) async {
        if (salio || !_sucio) return;
        await _confirmarSalida();
      },
      child: KunturScaffold(
        conAtras: true,
        // Mientras hay datos sin guardar se oculta la navegación inferior:
        // con `context.go` no pasaría por PopScope y se perdería el formulario.
        seccion: _sucio ? null : Seccion.administracion,
        alTocarInicio: _sucio ? _salirAInicio : null,
        maxAncho: 800,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Migas([
                Miga('Administración', ruta: _sucio ? null : AppRoutes.admin),
                if (_editando) Miga('Gestionar vuelos', ruta: _sucio ? null : AppRoutes.gestionVuelos),
                Miga(_editando ? 'Editar ${original?.codigo ?? ''}' : 'Nuevo vuelo'),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: AppDecorations.tarjeta,
                child: Form(
                  key: _formulario,
                  child: LayoutBuilder(
                    builder: (context, caja) {
                      final dosColumnas = caja.maxWidth >= 520;
                      Widget fila(Widget a, Widget b) => dosColumnas
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: a),
                              const SizedBox(width: 12),
                              Expanded(child: b),
                            ])
                          : Column(children: [a, const SizedBox(height: 14), b]);
                      final duracion = _duracionTexto;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            original == null ? 'Nuevo vuelo' : 'Editar vuelo ${original.codigo}',
                            style: AppTextStyles.titulo,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            original == null
                                ? 'El código (KT101, KT102…) se asigna solo y el vuelo nace con todos sus asientos libres.'
                                : 'El código no cambia. Un precio nuevo solo se cobra en las reservas que se hagan desde ahora.',
                            style: AppTextStyles.cuerpo,
                          ),
                          if (_rutaBloqueada) ...[
                            const SizedBox(height: 12),
                            AvisoInline(
                              tipo: TipoAviso.info,
                              texto: 'Este vuelo tiene ${original!.asientosVendidos} asiento(s) vendido(s): solo puede '
                                  'cambiar la fecha, las horas y el precio. Para cambiar la ruta o el avión, cancélelo '
                                  'y cree otro.',
                            ),
                          ],
                          const SizedBox(height: 16),
                          _vistaPrevia(),
                          const SizedBox(height: 20),
                          fila(origen, destino),
                          if (!_rutaBloqueada) ...[
                            const SizedBox(height: 10),
                            const Text('Ciudades frecuentes', style: AppTextStyles.nota),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                for (final ciudad in _ciudadesFrecuentes) _chipCiudad(ciudad),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          fecha,
                          const SizedBox(height: 14),
                          fila(salida, llegada),
                          if (duracion != null) ...[
                            const SizedBox(height: 10),
                            FilaDetalle(etiqueta: 'Duración estimada del vuelo', valor: duracion),
                          ],
                          const SizedBox(height: 14),
                          fila(precio, avion),
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            AvisoInline(texto: error),
                            if (desactualizado)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _recargar,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Recargar el vuelo'),
                                ),
                              ),
                          ],
                          const SizedBox(height: 22),
                          BotonDegradado(
                            texto: _editando ? 'Guardar cambios' : 'Crear vuelo',
                            cargando: enviando,
                            onPressed: _enviar,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
