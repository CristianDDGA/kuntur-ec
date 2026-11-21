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
import '../widgets/boton_degradado.dart';
import '../widgets/campo_selector.dart';
import '../widgets/campo_texto_kuntur.dart';
import '../widgets/estado_vista.dart';
import '../widgets/hoja_confirmacion.dart';
import '../widgets/insignia_estado.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/kuntur_scaffold.dart';
import '../widgets/navegacion_principal.dart';
import '../widgets/selectores_fecha_hora.dart';

/// Panel del administrador (V): acceso a crear vuelos y gestión del IVA.
/// Solo lo ve quien tiene rol admin (lo garantiza el router y, además, el servidor con 403).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iva = ref.watch(ivaControllerProvider);

    return KunturScaffold(
      seccion: Seccion.administracion,
      maxAncho: 680,
      onRefrescar: () async {
        ref.invalidate(ivaControllerProvider);
        // Espera la respuesta: así el indicador de refresco no termina antes de llegar los datos.
        await ref.read(ivaControllerProvider.future);
      },
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Administración', style: AppTextStyles.titulo),
          const SizedBox(height: 4),
          const Text('Gestione los vuelos y el impuesto que se cobra en las reservas.', style: AppTextStyles.cuerpo),
          const SizedBox(height: 16),
          _TarjetaVuelos(onCrear: () => context.push(AppRoutes.nuevoVuelo)),
          const SizedBox(height: 16),
          if (iva.isLoading && !iva.hasValue)
            const CargandoDetalleVista()
          else if (iva.hasError && !iva.hasValue)
            ErrorVista(
              mensaje: mensajeDeError(iva.error!),
              onReintentar: () => ref.invalidate(ivaControllerProvider),
            )
          else
            _SeccionIva(resumen: iva.value!),
        ],
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

  Future<DateTime?> _elegirFecha() => elegirFechaDeTarifa(context, inicial: _desde);

  Future<void> _enviar() async {
    if (_ocupado || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final texto = _porcentaje.text.trim().replaceAll(',', '.');
    final desde = _desde!;
    // Bloquea de inmediato: un doble toque no abre dos confirmaciones ni envía dos cambios.
    _ocupado = true;
    setState(() => _error = null);

    // Cambiar el impuesto afecta a todas las reservas nuevas: se pide confirmar.
    final actual = widget.resumen.vigente?.porcentajeCorto;
    final nuevo = _porcentajeCorto(texto);
    final desdeTexto = Formatos.fecha(desde);
    final confirmado = await mostrarConfirmacionKuntur(
      context,
      titulo: '¿Cambiar el IVA?',
      mensaje: actual == null
          ? 'No hay una tarifa vigente. Se programará $nuevo % desde el $desdeTexto. Las reservas ya hechas no cambian.'
          : 'El IVA pasará de $actual a $nuevo % desde el $desdeTexto.\n\n'
              'Las reservas ya hechas conservan el IVA con el que se cobraron.',
      textoConfirmar: 'Sí, cambiar',
      textoCancelar: 'Cancelar',
      icono: Icons.percent,
    );
    if (!mounted) return;
    if (!confirmado) {
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
    TarifaIva? programada;
    for (final t in widget.resumen.tarifas) {
      if (t.estado == EstadoTarifa.programada) {
        programada = t;
        break;
      }
    }
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
          else ...[
            BloqueMetricaIsometrico(
              etiqueta: 'IVA vigente',
              valor: OdometroCinetico(
                texto: vigente.porcentajeCorto,
                estilo: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.azul,
                  height: 1,
                ),
              ),
              pie: Text('vigente desde ${Formatos.fecha(vigente.vigenteDesde)}', style: AppTextStyles.cuerpo),
            ),
            const SizedBox(height: 10),
            // Línea de tiempo del impuesto: pasado, presente y futuro en una sola lectura.
            const Row(
              children: [
                Icon(Icons.timeline, size: 16, color: AppColors.textoSuave),
                SizedBox(width: 8),
                Text('Anterior · Ahora · Próxima', style: AppTextStyles.etiqueta),
              ],
            ),
          ],
          if (programada != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoSuave, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Próxima tarifa programada: ${programada.porcentajeCorto} desde el ${Formatos.fecha(programada.vigenteDesde)}',
                      style: AppTextStyles.cuerpo.copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                CampoTextoKuntur(
                  etiqueta: 'Nuevo porcentaje',
                  controlador: _porcentaje,
                  icono: Icons.percent,
                  mostrarLimpiar: true,
                  enabled: !_enviando,
                  hint: '15',
                  ayuda: 'De 0 a 100, hasta 2 decimales.',
                  inputFormatters: ValidadoresVuelo.entradaPorcentaje,
                  validador: ValidadoresVuelo.porcentaje,
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
          if (widget.resumen.tarifas.isEmpty)
            const VacioVista(
              icono: Icons.percent,
              titulo: 'Sin historial de tarifas',
              mensaje: 'Cuando programe la primera tarifa aparecerá aquí.',
              elevada: false,
            )
          else
            ...widget.resumen.tarifas.map((t) => _FilaTarifa(tarifa: t)),
        ],
      ),
    );
  }
}

/// "13.00" → "13", "12.50" → "12.5" (mismo formato que muestra una tarifa guardada).
String _porcentajeCorto(String texto) {
  final partes = texto.trim().split('.');
  final decimales = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return decimales.isEmpty ? partes[0] : '${partes[0]}.$decimales';
}

class _FilaTarifa extends StatelessWidget {  const _FilaTarifa({required this.tarifa});

  final TarifaIva tarifa;

  @override
  Widget build(BuildContext context) {
    final (texto, tipo) = switch (tarifa.estado) {
      EstadoTarifa.vigente => ('Vigente', TipoInsignia.exito),
      EstadoTarifa.programada => ('Programada', TipoInsignia.aviso),
      EstadoTarifa.anterior => ('Anterior', TipoInsignia.neutro),
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
          InsigniaEstado(texto: texto, tipo: tipo),
        ],
      ),
    );
  }
}
