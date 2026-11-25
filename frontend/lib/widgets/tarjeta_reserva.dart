import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import 'insignia_estado.dart';
import 'tarjeta_vuelo.dart';

/// Una reserva en el historial: vuelo, fecha, asientos, total tabular y estado.
class TarjetaReserva extends StatefulWidget {
  const TarjetaReserva({super.key, required this.reserva, required this.onTap});

  final Reserva reserva;
  final VoidCallback onTap;

  @override
  State<TarjetaReserva> createState() => _TarjetaReservaState();
}

class _TarjetaReservaState extends State<TarjetaReserva> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final reserva = widget.reserva;
    final v = reserva.vuelo;

    return Semantics(
      button: true,
      label: 'Reserva ${reserva.numero}, ${v.origen} a ${v.destino}, ${Formatos.dinero(reserva.totalCentavos)}',
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.985 : 1.0,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: Container(
          decoration: AppDecorations.tarjeta,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (valor) {
                if (_presionado != valor) setState(() => _presionado = valor);
              },
              hoverColor: AppColors.infoSuave.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CodigoVuelo(v.codigo),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reserva.numero,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.nota.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textoSecundario,
                              fontSize: 13,
                              fontFeatures: AppTextStyles.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        EtiquetaEstadoReserva(reserva: reserva),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${v.origen} → ${v.destino}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitulo.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Formatos.fecha(v.fecha)} · Salida ${Formatos.hora(v.horaSalida)}',
                                style: AppTextStyles.cuerpo.copyWith(
                                  fontSize: 13.5,
                                  fontFeatures: AppTextStyles.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total reserva', style: AppTextStyles.nota),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  Formatos.dinero(reserva.totalCentavos),
                                  softWrap: false,
                                  style: AppTextStyles.moneda.copyWith(
                                    fontSize: 20,
                                    color: reserva.cancelada ? AppColors.textoSuave : AppColors.textoPrincipal,
                                    decoration: reserva.cancelada ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.divisor),
                    Row(
                      children: [
                        const Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textoSecundario),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reserva.cantidad == 1 ? '1 asiento' : '${Formatos.entero(reserva.cantidad)} asientos',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cuerpo.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTextStyles.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Etiqueta visual integrada dentro del área clicable única de la tarjeta.
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.infoSuave,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borde),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_outlined, size: 15, color: AppColors.azul),
                                SizedBox(width: 6),
                                Text(
                                  'Ver detalle',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.azul),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Confirmada", "Cancelada", "Vuelo cancelado" (por la aerolínea) o "Vuelo realizado".
class EtiquetaEstadoReserva extends StatelessWidget {
  const EtiquetaEstadoReserva({super.key, required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    final (texto, tipo) = reserva.vuelo.cancelado
        ? ('Vuelo cancelado', TipoInsignia.error)
        : reserva.cancelada
            ? ('Cancelada', TipoInsignia.error)
            : reserva.vuelo.yaPartio()
                ? ('Vuelo realizado', TipoInsignia.neutro)
                : ('Confirmada', TipoInsignia.exito);
    return InsigniaEstado(texto: texto, tipo: tipo);
  }
}
