import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/iva_controller.dart';
import '../models/tarifa_iva.dart';
import '../models/validadores_vuelo.dart';
import '../models/vuelo.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/barra_kuntur.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';

/// Panel del administrador (V): acceso a crear vuelos y gestión del IVA.
/// Solo lo ve quien tiene rol admin (lo garantiza el router y, además, el servidor con 403).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iva = ref.watch(ivaControllerProvider);

    return Scaffold(
      appBar: const BarraKuntur(conAtras: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Administración', style: AppTextStyles.titulo),
                const SizedBox(height: 4),
                const Text('Gestione los vuelos y el impuesto que se cobra en las reservas.', style: AppTextStyles.cuerpo),
                const SizedBox(height: 16),
                _TarjetaVuelos(onCrear: () => context.push(AppRoutes.nuevoVuelo)),
                const SizedBox(height: 16),
                if (iva.isLoading && !iva.hasValue)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (iva.hasError && !iva.hasValue) ...[
                  AvisoInline(texto: mensajeDeError(iva.error!)),
                  const SizedBox(height: 12),
                  Align(
                    child: OutlinedButton.icon(
                      onPressed: () => ref.invalidate(ivaControllerProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ] else
                  _SeccionIva(resumen: iva.value!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaVuelos extends StatelessWidget {
  const _TarjetaVuelos({required this.onCrear});

  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.tarjeta,
        child: Row(
          children: [
            const Icon(Icons.flight_takeoff, color: AppColors.azul, size: 30),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vuelos', style: AppTextStyles.subtitulo),
                  SizedBox(height: 2),
                  Text('Programe un vuelo nuevo. El código se asigna solo.', style: AppTextStyles.cuerpo),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: onCrear, icon: const Icon(Icons.add), label: const Text('Crear')),
          ],
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
  bool _enviando = false; // hay una petición en curso (se muestra el indicador de carga)
  bool _ocupado = false; // confirmando o enviando: ignora toques repetidos
  String? _error;

  @override
  void dispose() {
    _porcentaje.dispose();
    super.dispose();
  }

  Future<DateTime?> _elegirFecha() {
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return showDatePicker(
      context: context,
      initialDate: _desde ?? dia,
      firstDate: dia,
      lastDate: dia.add(const Duration(days: ValidadoresVuelo.diasMaxAdelante)),
      helpText: 'La tarifa rige desde',
    );
  }

  Future<void> _enviar() async {
    if (_ocupado || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final texto = _porcentaje.text.trim().replaceAll(',', '.');
    final desde = _desde!;
    // Bloquea de inmediato: un doble toque no abre dos confirmaciones ni envía dos cambios.
    _ocupado = true;
    setState(() => _error = null);

    // Cambiar el impuesto afecta a todas las reservas nuevas: se pide confirmar.
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cambiar el IVA?'),
        content: Text(
          'El IVA será de $texto % desde el ${Formatos.fecha(desde)}.\n\n'
          'Las reservas ya hechas conservan el IVA con el que se cobraron.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cambiar')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmado != true) {
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.percent, color: AppColors.azul, size: 28),
              SizedBox(width: 12),
              Text('IVA', style: AppTextStyles.subtitulo),
            ],
          ),
          const SizedBox(height: 14),
          if (vigente == null)
            const AvisoInline(
              tipo: TipoAviso.error,
              texto: 'No hay una tarifa de IVA vigente: nadie podrá reservar hasta que programe una.',
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(vigente.porcentajeCorto,
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.azul, height: 1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('vigente desde ${Formatos.fecha(vigente.vigenteDesde)}', style: AppTextStyles.cuerpo),
                ),
              ],
            ),
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
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _porcentaje,
                  enabled: !_enviando,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: ValidadoresVuelo.entradaPorcentaje,
                  decoration: InputDecoration(
                    labelText: 'Nuevo porcentaje',
                    hintText: '15',
                    helperText: 'De 0 a 100, hasta 2 decimales.',
                    prefixIcon: const Icon(Icons.percent),
                    suffixIcon: ListenableBuilder(
                      listenable: _porcentaje,
                      builder: (_, _) => _porcentaje.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Borrar',
                              icon: const Icon(Icons.close),
                              onPressed: () => _porcentaje.clear(),
                            ),
                    ),
                  ),
                  validator: ValidadoresVuelo.porcentaje,
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
          for (final t in widget.resumen.tarifas) _FilaTarifa(tarifa: t),
        ],
      ),
    );
  }
}

class _FilaTarifa extends StatelessWidget {
  const _FilaTarifa({required this.tarifa});

  final TarifaIva tarifa;

  @override
  Widget build(BuildContext context) {
    final (texto, color, fondo) = switch (tarifa.estado) {
      EstadoTarifa.vigente => ('Vigente', AppColors.exito, AppColors.exitoSuave),
      EstadoTarifa.programada => ('Programada', AppColors.aviso, AppColors.avisoSuave),
      EstadoTarifa.anterior => ('Anterior', AppColors.textoSecundario, AppColors.divisor),
    };
    final hasta = tarifa.vigenteHasta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(tarifa.porcentajeCorto, style: AppTextStyles.subtitulo.copyWith(fontSize: 16)),
          ),
          Expanded(
            child: Text(
              hasta == null
                  ? 'Desde ${Formatos.fecha(tarifa.vigenteDesde)}'
                  : '${Formatos.fecha(tarifa.vigenteDesde)} → ${Formatos.fecha(hasta.subtract(const Duration(days: 1)))}',
              style: AppTextStyles.cuerpo,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
            child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
