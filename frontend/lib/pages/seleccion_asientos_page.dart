import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/barra_kuntur.dart';
import '../widgets/boton_degradado.dart';
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
      loading: () => const Scaffold(appBar: BarraKuntur(conAtras: true), body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: const BarraKuntur(conAtras: true),
        body: Padding(padding: const EdgeInsets.all(16), child: AvisoInline(texto: mensajeDeError(e))),
      ),
      data: (r) => r.puedeEditarse()
          ? _Mapa(vueloId: r.vueloId, reserva: r)
          : const Scaffold(
              appBar: BarraKuntur(conAtras: true),
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
        final salir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Salir sin guardar?'),
            content: Text(_editando
                ? 'Los cambios en sus asientos no se guardarán.'
                : 'Los asientos que eligió no se reservarán.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir eligiendo')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
            ],
          ),
        );
        if (salir == true && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: const BarraKuntur(conAtras: true),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _contenido(vuelo, mapa, iva?.porcentaje),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(AsyncValue<Vuelo> vuelo, AsyncValue<MapaAsientos> mapa, String? ivaPorcentaje) {
    if ((vuelo.isLoading && !vuelo.hasValue) || (mapa.isLoading && !mapa.hasValue)) {
      return const Center(child: CircularProgressIndicator());
    }
    final fallo = (vuelo.hasValue ? null : vuelo.error) ?? (mapa.hasValue ? null : mapa.error);
    if (fallo != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvisoInline(texto: mensajeDeError(fallo)),
            const SizedBox(height: 12),
            Align(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(vueloDetalleControllerProvider(widget.vueloId));
                  ref.invalidate(mapaAsientosControllerProvider(widget.vueloId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
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
                      const Miga('Mis reservas', ruta: AppRoutes.reservas),
                      Miga(widget.reserva!.numero, ruta: AppRoutes.reserva(widget.reserva!.id)),
                      const Miga('Cambiar asientos'),
                    ]
                  : [
                      const Miga('Vuelos', ruta: AppRoutes.inicio),
                      Miga(v.codigo, ruta: AppRoutes.vuelo(v.id)),
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

/// Las filas de asientos, con un pasillo entre las dos mitades de columnas.
class _Cabina extends StatelessWidget {
  const _Cabina({required this.mapa, required this.ocupados, required this.seleccion, required this.onTocar});

  final MapaAsientos mapa;
  final Set<String> ocupados;
  final SeleccionAsientos seleccion;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) {
    final mitad = mapa.columnas.length ~/ 2;
    Widget asiento(int fila, int columna) {
      final numero = mapa.asiento(fila, columna);
      if (numero == null) return const SizedBox(width: AsientoBoton.tamano, height: AsientoBoton.tamano);
      final estado = ocupados.contains(numero)
          ? EstadoAsiento.ocupado
          : seleccion.contiene(numero)
              ? EstadoAsiento.seleccionado
              : EstadoAsiento.libre;
      return AsientoBoton(
        numero: numero,
        estado: estado,
        atenuado: seleccion.llena && estado == EstadoAsiento.libre,
        onTap: () => onTocar(numero),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: AppDecorations.tarjeta,
      child: Column(
        children: [
          Text('Frente del avión', style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var fila = 1; fila <= mapa.filas; fila++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 26, child: Text('$fila', textAlign: TextAlign.center, style: AppTextStyles.nota)),
                for (var c = 0; c < mitad; c++) asiento(fila, c),
                const SizedBox(width: 22), // pasillo
                for (var c = mitad; c < mapa.columnas.length; c++) asiento(fila, c),
                const SizedBox(width: 26),
              ],
            ),
        ],
      ),
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
        boxShadow: [BoxShadow(color: AppColors.azul.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, -4))],
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
                    Text(
                      'Asientos (${seleccion.cantidad} de ${SeleccionAsientos.maximo}): $lista',
                      style: AppTextStyles.cuerpo.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              Text(
                Formatos.dinero(subtotal + (iva ?? 0)),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.azul),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: enviando || (seleccion.vacia && !editando) || sinCambios ? null : onReiniciar,
                icon: const Icon(Icons.restart_alt),
                label: Text(editando ? 'Restablecer' : 'Reiniciar selección'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BotonDegradado(
                  texto: editando ? 'Guardar cambios' : 'Confirmar reserva',
                  cargando: enviando,
                  onPressed: puedeConfirmar ? onConfirmar : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
