import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/crear_vuelo_controller.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';
import '../widgets/campo_texto_kuntur.dart';
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

/// Formulario "Nuevo vuelo" (V). Solo el administrador llega aquí (lo garantiza el router
/// y, en última instancia, el servidor con 403).
class CrearVueloPage extends ConsumerStatefulWidget {
  const CrearVueloPage({super.key});

  @override
  ConsumerState<CrearVueloPage> createState() => _CrearVueloPageState();
}

class _CrearVueloPageState extends ConsumerState<CrearVueloPage> {
  final _formulario = GlobalKey<FormState>();
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _precio = TextEditingController();
  final _capacidad = TextEditingController();
  DateTime? _fecha;
  Duration? _salida;
  Duration? _llegada;

  @override
  void initState() {
    super.initState();
    // PopScope necesita saber si hay datos escritos para preguntar antes de salir.
    for (final c in [_origen, _destino, _precio, _capacidad]) {
      c.addListener(_alCambiar);
    }
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_origen, _destino, _precio, _capacidad]) {
      c.removeListener(_alCambiar);
      c.dispose();
    }
    super.dispose();
  }

  /// Hay algo escrito o elegido: salir sin guardar perdería el formulario.
  bool get _sucio =>
      [_origen, _destino, _precio, _capacidad].any((c) => c.text.trim().isNotEmpty) ||
      _fecha != null ||
      _salida != null ||
      _llegada != null;

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final vuelo = await ref.read(crearVueloControllerProvider.notifier).crear(NuevoVuelo(
          origen: ValidadoresVuelo.normalizarTexto(_origen.text),
          destino: ValidadoresVuelo.normalizarTexto(_destino.text),
          fecha: _fecha!,
          horaSalida: _salida!,
          horaLlegada: _llegada!,
          precio: ValidadoresVuelo.normalizarPrecio(_precio.text),
          capacidad: int.parse(_capacidad.text.trim()),
        ));
    if (vuelo != null && mounted) {
      mostrarAviso(context, 'Vuelo ${vuelo.codigo} creado correctamente.');
      context.pushReplacement(AppRoutes.vuelo(vuelo.id));
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

  /// Filas de la cabina **3 + pasillo + 3** para la capacidad escrita, o `null`
  /// mientras la capacidad no sea un entero válido.
  int? get _filasCabina {
    final capacidad = int.tryParse(_capacidad.text.trim());
    if (capacidad == null || capacidad < 1 || capacidad > ValidadoresVuelo.capacidadMax) return null;
    return (capacidad / 6).ceil();
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
        titulo: '¿Salir sin crear el vuelo?',
        mensaje: 'Los datos que escribió se perderán.',
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

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(crearVueloControllerProvider);
    final enviando = estado.isLoading;
    final error = estado.hasError && !enviando ? mensajeDeError(estado.error!) : null;

    final origen = CampoTextoKuntur(
      etiqueta: 'Origen',
      controlador: _origen,
      icono: Icons.flight_takeoff,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
      validador: (v) => ValidadoresVuelo.ciudad(v, nombre: 'El origen'),
    );
    final destino = CampoTextoKuntur(
      etiqueta: 'Destino',
      controlador: _destino,
      icono: Icons.flight_land,
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
    final capacidad = CampoTextoKuntur(
      etiqueta: 'Capacidad (asientos)',
      controlador: _capacidad,
      icono: Icons.event_seat_outlined,
      mostrarLimpiar: true,
      hint: '80',
      ayuda: 'De 1 a ${ValidadoresVuelo.capacidadMax} asientos.',
      tipoTeclado: TextInputType.number,
      inputFormatters: ValidadoresVuelo.entradaCapacidad,
      textInputAction: TextInputAction.done,
      onEnviado: (_) => _enviar(),
      validador: ValidadoresVuelo.capacidad,
    );
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
        maxAncho: 640,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Migas([
                Miga('Administración', ruta: _sucio ? null : AppRoutes.admin),
                const Miga('Nuevo vuelo'),
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
                          const Text('Nuevo vuelo', style: AppTextStyles.titulo),
                          const SizedBox(height: 4),
                          const Text(
                            'El código (KT101, KT102…) se asigna solo y el vuelo nace con todos sus asientos libres.',
                            style: AppTextStyles.cuerpo,
                          ),
                          const SizedBox(height: 16),
                          _vistaPrevia(),
                          const SizedBox(height: 20),
                          fila(origen, destino),
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
                          const SizedBox(height: 14),
                          fecha,
                          const SizedBox(height: 14),
                          fila(salida, llegada),
                          if (duracion != null) ...[
                            const SizedBox(height: 10),
                            FilaDetalle(etiqueta: 'Duración estimada del vuelo', valor: duracion),
                          ],
                          const SizedBox(height: 14),
                          fila(precio, capacidad),
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            AvisoInline(texto: error),
                          ],
                          const SizedBox(height: 22),
                          BotonDegradado(texto: 'Crear vuelo', cargando: enviando, onPressed: _enviar),
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
