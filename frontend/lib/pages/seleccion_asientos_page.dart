import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/iva_controller.dart';
import '../controllers/mapa_asientos_controller.dart';
import '../controllers/reserva_detalle_controller.dart';
import '../controllers/reservar_controller.dart';
import '../controllers/vuelo_detalle_controller.dart';
import '../models/asientos.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/asiento_boton.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/estado_vista.dart';
import '../widgets/hoja_confirmacion.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/migas.dart';
import '../widgets/tarjeta_vuelo.dart';

/// Elegir asientos en el mapa del avión (V).
///
/// Dos usos: reservar un vuelo ([vueloId]) o cambiar los asientos de una reserva ([reservaId]).
class SeleccionAsientosPage extends ConsumerWidget {
  const SeleccionAsientosPage({super.key, this.vueloId, this.reservaId})
      : assert((vueloId == null) != (reservaId == null), 'Indique vueloId (reservar) o reservaId (modificar).');

  final int? vueloId;
  final int? reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reservaId == null) return _Mapa(vueloId: vueloId!);

    // Modificar: primero se lee la reserva para saber el vuelo y los asientos actuales.
    final reserva = ref.watch(reservaDetalleControllerProvider(reservaId!));
    return reserva.when(
      loading: () => const KunturScaffold(
        conAtras: true,
        maxAncho: 1000,
        body: Padding(padding: EdgeInsets.all(16), child: CargandoDetalleVista()),
      ),
      error: (e, _) => KunturScaffold(
        conAtras: true,
        maxAncho: 1000,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorVista(
            mensaje: mensajeDeError(e),
            onReintentar: () => ref.invalidate(reservaDetalleControllerProvider(reservaId!)),
          ),
        ),
      ),
      data: (r) => r.puedeEditarse()
          ? _Mapa(vueloId: r.vueloId, reserva: r)
          : const KunturScaffold(
              conAtras: true,
              maxAncho: 1000,
              body: Padding(
                padding: EdgeInsets.all(16),
                child: AvisoInline(
                  tipo: TipoAviso.info,
                  texto: 'Esta reserva ya no se puede modificar (está cancelada o el vuelo ya partió).',
                ),
              ),
            ),
    );
  }
}

class _Mapa extends ConsumerStatefulWidget {
  const _Mapa({required this.vueloId, this.reserva});

  final int vueloId;

  /// Si viene, se están cambiando los asientos de esta reserva.
  final Reserva? reserva;

  @override
  ConsumerState<_Mapa> createState() => _MapaState();
}

class _MapaState extends ConsumerState<_Mapa> {
  late SeleccionAsientos _seleccion = SeleccionAsientos(widget.reserva?.asientos.toSet() ?? const {});
  bool _enviando = false;
  String? _error;
  bool _conflicto = false;

  bool get _editando => widget.reserva != null;

  /// Asientos con los que empezó la reserva (al modificar). El mapa los muestra como libres para su dueño.
  Set<String> get _propios => widget.reserva?.asientos.toSet() ?? const {};

  bool get _sinCambios => _editando && _seleccion == SeleccionAsientos(_propios);

  void _alternar(String asiento) {
    final antes = _seleccion;
    final despues = antes.alternar(asiento);
    if (identical(antes, despues)) {
      mostrarAviso(context, 'Máximo ${SeleccionAsientos.maximo} asientos por reserva.');
      return;
    }
    setState(() {
      _seleccion = despues;
      _error = null;
      _conflicto = false;
    });
  }

  /// Vuelve a dejar la selección como al entrar: en blanco al reservar, con los asientos originales al modificar.
  void _reiniciar() => setState(() {
        _seleccion = SeleccionAsientos(_propios);
        _error = null;
        _conflicto = false;
      });

  Future<void> _actualizarMapa() async {
    await ref.read(mapaAsientosControllerProvider(widget.vueloId).notifier).recargar();
    final mapa = ref.read(mapaAsientosControllerProvider(widget.vueloId)).value;
    if (mapa != null && mounted) {
      // Si mientras tanto alguien tomó un asiento ya marcado, se quita de la selección.
      final tomados = _seleccion.elegidos.where((a) => mapa.ocupados.contains(a) && !_propios.contains(a));
      if (tomados.isNotEmpty) setState(() => _seleccion = _seleccion.sin(tomados));
    }
  }

  Future<void> _confirmar() async {
    if (_enviando || _seleccion.vacia) return;
    setState(() {
      _enviando = true;
      _error = null;
      _conflicto = false;
    });
    try {
      if (_editando) {
        await ref.read(reservaDetalleControllerProvider(widget.reserva!.id).notifier).modificar(_seleccion.ordenados);
        if (!mounted) return;
        mostrarAviso(context, 'Reserva modificada.');
        context.pop();
      } else {
        final nueva = await ref.read(reservarControllerProvider.notifier).reservar(
              vueloId: widget.vueloId,
              asientos: _seleccion.ordenados,
            );
        if (!mounted) return;
        if (nueva != null) {
          mostrarAviso(context, 'Reserva ${nueva.numero} confirmada.');
          context.pushReplacement(AppRoutes.reserva(nueva.id));
          return;
        }
        final falla = ref.read(reservarControllerProvider).error;
        if (falla != null) throw falla;
      }
    } catch (e) {
      if (!mounted) return;
      final ocupados = e is ServerFailure ? e.asientosOcupados : const <String>[];
      setState(() {
        _error = mensajeDeError(e);
        _conflicto = ocupados.isNotEmpty;
        if (ocupados.isNotEmpty) _seleccion = _seleccion.sin(ocupados); // ya no están libres
      });
      // Al reservar, el controlador ya vuelve a pedir el mapa (con éxito o sin él); al modificar lo hacemos aquí.
      if (_editando && e is ServerFailure && e.statusCode == 409) {
        await _actualizarMapa(); // se ve lo que quedó libre
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vuelo = ref.watch(vueloDetalleControllerProvider(widget.vueloId));
    final mapa = ref.watch(mapaAsientosControllerProvider(widget.vueloId));
    final iva = ref.watch(ivaVigenteProvider).value;
    ref.watch(reservarControllerProvider); // lo mantiene vivo mientras se reserva (guarda el error del servidor)

    // Con asientos elegidos (o cambios sin guardar) la flecha "Volver" pregunta antes de salir.
    final conCambios = !_enviando && (_editando ? !_sinCambios : !_seleccion.vacia);

    return PopScope(
      canPop: !conCambios,
      onPopInvokedWithResult: (salio, _) async {
        if (salio) return;
        final salir = await _confirmarSalida();
        if (salir && context.mounted) context.pop();
      },
      child: KunturScaffold(
        conAtras: true,
        // Mientras hay asientos elegidos, el logo confirma antes de salir (context.go no pasa por PopScope).
        alTocarInicio: conCambios ? _salirAInicio : null,
        maxAncho: 1000,
        body: _contenido(vuelo, mapa, iva?.porcentaje, conCambios),
      ),
    );
  }

  Future<bool> _confirmarSalida() => mostrarConfirmacionKuntur(
        context,
        titulo: '¿Salir sin guardar?',
        mensaje: _editando
            ? 'Los cambios en sus asientos no se guardarán.'
            : 'Los asientos que eligió no se reservarán.',
        textoConfirmar: 'Salir',
        textoCancelar: 'Seguir eligiendo',
        estilo: EstiloConfirmacion.destructiva,
        icono: Icons.event_seat_outlined,
      );

  Future<void> _salirAInicio() async {
    if (await _confirmarSalida() && mounted) context.go(AppRoutes.vuelos);
  }

  Widget _contenido(AsyncValue<Vuelo> vuelo, AsyncValue<MapaAsientos> mapa, String? ivaPorcentaje, bool conCambios) {
    if ((vuelo.isLoading && !vuelo.hasValue) || (mapa.isLoading && !mapa.hasValue)) {
      return const Padding(padding: EdgeInsets.all(16), child: CargandoDetalleVista());
    }
    final fallo = (vuelo.hasValue ? null : vuelo.error) ?? (mapa.hasValue ? null : mapa.error);
    if (fallo != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorVista(
          mensaje: mensajeDeError(fallo),
          onReintentar: () {
            ref.invalidate(vueloDetalleControllerProvider(widget.vueloId));
            ref.invalidate(mapaAsientosControllerProvider(widget.vueloId));
          },
        ),
      );
    }

    final v = vuelo.value!;
    final m = mapa.value!;
    // Al modificar, los asientos de la propia reserva figuran como ocupados en el servidor: para su dueño están libres.
    final ocupados = m.ocupados.difference(_propios);
    final actualizando = mapa.isLoading;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              Migas(_editando
                  ? [
                      Miga('Mis reservas', ruta: conCambios ? null : AppRoutes.reservas),
                      Miga(widget.reserva!.numero, ruta: conCambios ? null : AppRoutes.reserva(widget.reserva!.id)),
                      const Miga('Cambiar asientos'),
                    ]
                  : [
                      Miga('Vuelos', ruta: conCambios ? null : AppRoutes.vuelos),
                      Miga(v.codigo, ruta: conCambios ? null : AppRoutes.vuelo(v.id)),
                      const Miga('Elegir asientos'),
                    ]),
              const SizedBox(height: 10),
              _CabeceraVuelo(vuelo: v, onActualizar: actualizando ? null : _actualizarMapa, libres: m.libres),
              const SizedBox(height: 12),
              Text(
                _editando
                    ? 'Toque un asiento para soltarlo o elegir otro. Los marcados en rojo son de otras personas.'
                    : 'Toque los asientos que quiere (hasta ${SeleccionAsientos.maximo}). Los marcados en rojo ya están ocupados.',
                style: AppTextStyles.cuerpo,
              ),
              const SizedBox(height: 10),
              const _Leyenda(),
              const SizedBox(height: 12),
              Opacity(
                opacity: actualizando ? 0.5 : 1,
                child: _Cabina(mapa: m, ocupados: ocupados, seleccion: _seleccion, onTocar: _alternar),
              ),
            ],
          ),
        ),
        _Resumen(
          vuelo: v,
          seleccion: _seleccion,
          reserva: widget.reserva,
          ivaPorcentaje: ivaPorcentaje,
          error: _error,
          conflicto: _conflicto,
          enviando: _enviando,
          sinCambios: _sinCambios,
          onReiniciar: _reiniciar,
          onConfirmar: _confirmar,
        ),
      ],
    );
  }
}

class _CabeceraVuelo extends StatelessWidget {
  const _CabeceraVuelo({required this.vuelo, required this.onActualizar, required this.libres});

  final Vuelo vuelo;
  final VoidCallback? onActualizar;
  final int libres;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.tarjeta,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CodigoVuelo(vuelo.codigo),
                      const SizedBox(width: 8),
                      Expanded(child: Text(Formatos.fecha(vuelo.fecha), style: AppTextStyles.cuerpo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${vuelo.origen} → ${vuelo.destino}', style: AppTextStyles.subtitulo),
                  const SizedBox(height: 2),
                  Text(
                    '${Formatos.hora(vuelo.horaSalida)} · ${Formatos.dinero(vuelo.precioCentavos)} por asiento · $libres libres',
                    style: AppTextStyles.nota,
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Actualizar mapa',
              onPressed: onActualizar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _Muestra(AppColors.superficie, AppColors.azul, 'Disponible'),
          _Muestra(AppColors.azul, AppColors.azul, 'Seleccionado'),
          _Muestra(AppColors.errorSuave, AppColors.error, 'Ocupado'),
        ],
      );
}

class _Muestra extends StatelessWidget {
  const _Muestra(this.fondo, this.borde, this.texto);

  final Color fondo;
  final Color borde;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borde.withValues(alpha: 0.7), width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(texto, style: AppTextStyles.nota.copyWith(fontSize: 13)),
        ],
      );
}

/// Las filas de asientos en la distribución visual **3 + pasillo + 3**.
///
/// El contrato del backend no cambia (A–D por fila lógica): la secuencia lineal
/// [MapaAsientos.todos] se reparte en filas visuales de 6 asientos, 3 a cada
/// lado del pasillo central, conservando los códigos reales de cada asiento.
class _Cabina extends StatelessWidget {
  const _Cabina({required this.mapa, required this.ocupados, required this.seleccion, required this.onTocar});

  final MapaAsientos mapa;
  final Set<String> ocupados;
  final SeleccionAsientos seleccion;
  final ValueChanged<String> onTocar;

  /// Asientos por lado del pasillo.
  static const int columnasPorLado = 3;

  /// Asientos por fila visual: 3 + 3.
  static const int porFila = columnasPorLado * 2;

  /// Ancho del pasillo central.
  static const double _pasillo = 18;

  /// Ancho del indicador de fila lógica (a la izquierda).
  static const double _indicador = 26;

  /// Holgura reservada para que la fila nunca desborde.
  static const double _holgura = 8;

  static const List<String> _posicionesIzquierda = ['I', 'II', 'III'];
  static const List<String> _posicionesDerecha = ['IV', 'V', 'VI'];

  @override
  Widget build(BuildContext context) {
    final todos = mapa.todos;
    final filasVisuales = (todos.length + porFila - 1) ~/ porFila;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: AppDecorations.tarjeta,
      child: Column(
        children: [
          // Proa isométrica 2.5D: sustituye la silueta plana de la cabina.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: ProaIsometricaAvion(alto: 54),
          ),
          Text('Frente del avión', style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, caja) {
              // 6 butacas (44–48) + pasillo (18) + indicador (26) + holgura (8).
              final lado = ((caja.maxWidth - _pasillo - _indicador - _holgura) / porFila).clamp(44.0, 48.0);
              final ancho = lado * porFila + _pasillo + _indicador;
              final tablero = _tablero(lado, filasVisuales, todos);
              if (caja.maxWidth >= ancho) return Center(child: tablero);
              // En anchos menores que el mínimo HIG (menos de 340 pt de pantalla)
              // se escala el tablero para no desbordar el contenedor.
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(width: ancho, child: tablero),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tablero(double lado, int filasVisuales, List<String> todos) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _encabezado(lado),
          const SizedBox(height: 2),
          Text(
            'Ventana · Pasillo · Ventana',
            textAlign: TextAlign.center,
            style: AppTextStyles.nota.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 6),
          for (var fila = 0; fila < filasVisuales; fila++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _fila(fila, lado, todos),
            ),
        ],
      );

  /// Encabezado superior de las 6 posiciones (`I II III | IV V VI`).
  Widget _encabezado(double lado) {
    Widget posicion(String etiqueta) => SizedBox(
          width: lado,
          child: Center(
            child: Text(etiqueta, style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: _indicador),
        for (final etiqueta in _posicionesIzquierda) posicion(etiqueta),
        SizedBox(
          width: _pasillo,
          child: Center(
            child: Text('|', style: AppTextStyles.nota.copyWith(color: AppColors.borde, fontWeight: FontWeight.w700)),
          ),
        ),
        for (final etiqueta in _posicionesDerecha) posicion(etiqueta),
      ],
    );
  }

  Widget _fila(int filaVisual, double lado, List<String> todos) {
    final base = filaVisual * porFila;
    final numeros = [
      for (var posicion = 0; posicion < porFila; posicion++)
        base + posicion < todos.length ? todos[base + posicion] : null,
    ];
    // Fila lógica real del primer asiento de esta fila visual.
    final primerAsiento = numeros.firstWhere((numero) => numero != null)!;
    final filaLogica = int.parse(primerAsiento.substring(0, primerAsiento.length - 1));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _indicador,
          child: Text('$filaLogica', textAlign: TextAlign.center, style: AppTextStyles.nota),
        ),
        for (var posicion = 0; posicion < porFila; posicion++) ...[
          if (posicion == columnasPorLado) const SizedBox(width: _pasillo, height: 1),
          _celda(numeros[posicion], lado),
        ],
      ],
    );
  }

  Widget _celda(String? numero, double lado) {
    if (numero == null) return SizedBox(width: lado, height: lado);
    final estado = ocupados.contains(numero)
        ? EstadoAsiento.ocupado
        : seleccion.contiene(numero)
            ? EstadoAsiento.seleccionado
            : EstadoAsiento.libre;
    return AsientoBoton(
      numero: numero,
      estado: estado,
      atenuado: seleccion.llena && estado == EstadoAsiento.libre,
      lado: lado,
      onTap: () => onTocar(numero),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.vuelo,
    required this.seleccion,
    required this.reserva,
    required this.ivaPorcentaje,
    required this.error,
    required this.conflicto,
    required this.enviando,
    required this.sinCambios,
    required this.onReiniciar,
    required this.onConfirmar,
  });

  final Vuelo vuelo;
  final SeleccionAsientos seleccion;
  final Reserva? reserva;
  final String? ivaPorcentaje;
  final String? error;
  final bool conflicto;
  final bool enviando;
  final bool sinCambios;
  final VoidCallback onReiniciar;
  final VoidCallback onConfirmar;

  /// IVA = subtotal × porcentaje, redondeado al centavo (mitad hacia arriba), solo con enteros.
  static int _iva(int subtotal, String porcentaje) {
    final partes = porcentaje.split('.');
    final centesimas = int.parse(partes[0]) * 100 + int.parse((partes.length > 1 ? partes[1] : '').padRight(2, '0'));
    return (subtotal * centesimas + 5000) ~/ 10000;
  }

  @override
  Widget build(BuildContext context) {
    final editando = reserva != null;
    // Al modificar se conservan el precio y el IVA con los que se reservó; al reservar, los vigentes.
    final unitario = editando ? reserva!.subtotalCentavos ~/ reserva!.cantidad : vuelo.precioCentavos;
    final porcentaje = editando ? reserva!.ivaPorcentaje : ivaPorcentaje;
    final subtotal = unitario * seleccion.cantidad;
    final iva = porcentaje == null ? null : _iva(subtotal, porcentaje);
    final lista = seleccion.vacia ? 'Ninguno' : seleccion.ordenados.join(', ');
    final puedeConfirmar = !seleccion.vacia && !sinCambios && !enviando;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            AvisoInline(tipo: conflicto ? TipoAviso.info : TipoAviso.error, texto: error!),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La línea de asientos se reacomoda con AnimatedSize (Reduce Motion
                    // la deja quieta); hay un solo Text, así find.text sigue encontrándolo.
                    AnimatedSize(
                      duration: AppMotion.mediaDe(context),
                      curve: AppMotion.curvaEntrada,
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Asientos (${seleccion.cantidad} de ${SeleccionAsientos.maximo}): $lista',
                        style: AppTextStyles.cuerpo.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (iva == null)
                      Text('Subtotal ${Formatos.dinero(subtotal)} · el IVA se calcula al confirmar', style: AppTextStyles.nota)
                    else
                      Text(
                        'Subtotal ${Formatos.dinero(subtotal)} + IVA ${Formatos.porcentaje(porcentaje!)} ${Formatos.dinero(iva)}',
                        style: AppTextStyles.nota,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Total cinético: cada cambio de la selección reasienta el monto.
              OdometroCinetico(
                texto: Formatos.dinero(subtotal + (iva ?? 0)),
                estilo: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.azul),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // En pantallas angostas las acciones se apilan: nunca desbordan.
          LayoutBuilder(
            builder: (context, caja) {
              final reiniciar = TextButton.icon(
                onPressed: enviando || (seleccion.vacia && !editando) || sinCambios ? null : onReiniciar,
                icon: const Icon(Icons.restart_alt),
                label: Text(editando ? 'Restablecer' : 'Reiniciar selección'),
              );
              final confirmar = BotonDegradado(
                texto: editando ? 'Guardar cambios' : 'Confirmar reserva',
                cargando: enviando,
                onPressed: puedeConfirmar ? onConfirmar : null,
              );
              if (caja.maxWidth < 390) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [confirmar, reiniciar],
                );
              }
              return Row(
                children: [
                  reiniciar,
                  const SizedBox(width: 8),
                  Expanded(child: confirmar),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
