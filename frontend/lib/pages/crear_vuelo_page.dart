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
import '../widgets/barra_kuntur.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';

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
  void dispose() {
    for (final c in [_origen, _destino, _precio, _capacidad]) {
      c.dispose();
    }
    super.dispose();
  }

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

  /// Si el vuelo es hoy se propone la próxima hora completa; si no, las 08:00.
  Duration _salidaSugerida() {
    final ahora = DateTime.now();
    final f = _fecha;
    final hoy = f != null && f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
    if (!hoy) return const Duration(hours: 8);
    return ahora.hour < 23 ? Duration(hours: ahora.hour + 1) : const Duration(hours: 23, minutes: 59);
  }

  /// "X" para vaciar un campo de un toque; solo aparece cuando hay algo escrito.
  Widget? _botonLimpiar(TextEditingController c) => ListenableBuilder(
        listenable: c,
        builder: (_, _) => c.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.close),
                onPressed: () {
                  c.clear();
                  _formulario.currentState?.validate();
                },
              ),
      );

  /// Selector de hora en formato 24 h. Si aún no hay hora, propone [sugerida].
  Future<Duration?> _elegirHora(Duration? actual, String ayuda, {Duration sugerida = const Duration(hours: 8)}) async {
    final inicial = actual ?? sugerida;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: inicial.inHours % 24, minute: inicial.inMinutes % 60),
      helpText: ayuda,
      builder: (context, hijo) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: hijo!,
      ),
    );
    return hora == null ? null : Duration(hours: hora.hour, minutes: hora.minute);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(crearVueloControllerProvider);
    final enviando = estado.isLoading;
    final error = estado.hasError && !enviando ? mensajeDeError(estado.error!) : null;

    final origen = TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _origen,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Origen', prefixIcon: Icon(Icons.flight_takeoff)),
      validator: (v) => ValidadoresVuelo.ciudad(v, nombre: 'El origen'),
    );
    final destino = TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _destino,
      inputFormatters: ValidadoresVuelo.entradaCiudad,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Destino', prefixIcon: Icon(Icons.flight_land)),
      validator: (v) => ValidadoresVuelo.destinoDistinto(v, _origen.text),
    );
    final precio = TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _precio,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: ValidadoresVuelo.entradaPrecio,
      decoration: InputDecoration(
        labelText: 'Precio por persona (USD)',
        hintText: '75.50',
        helperText: 'Máximo \$10000, hasta 2 decimales.',
        prefixIcon: const Icon(Icons.attach_money),
        suffixIcon: _botonLimpiar(_precio),
      ),
      validator: ValidadoresVuelo.precio,
    );
    final capacidad = TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _capacidad,
      keyboardType: TextInputType.number,
      inputFormatters: ValidadoresVuelo.entradaCapacidad,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _enviar(),
      decoration: InputDecoration(
        labelText: 'Capacidad (asientos)',
        hintText: '80',
        helperText: 'De 1 a ${ValidadoresVuelo.capacidadMax} asientos.',
        prefixIcon: const Icon(Icons.event_seat_outlined),
        suffixIcon: _botonLimpiar(_capacidad),
      ),
      validator: ValidadoresVuelo.capacidad,
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

    return Scaffold(
      appBar: const BarraKuntur(conAtras: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Nuevo vuelo', style: AppTextStyles.titulo),
                          const SizedBox(height: 4),
                          const Text(
                            'El código (KT101, KT102…) se asigna solo y el vuelo nace con todos sus asientos libres.',
                            style: AppTextStyles.cuerpo,
                          ),
                          const SizedBox(height: 20),
                          fila(origen, destino),
                          const SizedBox(height: 14),
                          fecha,
                          const SizedBox(height: 14),
                          fila(salida, llegada),
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
            ),
          ),
        ),
      ),
    );
  }
}
