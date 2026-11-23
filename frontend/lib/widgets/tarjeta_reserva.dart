import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import 'insignia_estado.dart';
import 'tarjeta_vuelo.dart';

/// Una reserva en el historial: vuelo, fecha, asientos, total y estado.
class TarjetaReserva extends StatelessWidget {
  const TarjetaReserva({super.key, required this.reserva, required this.onTap});

  final Reserva reserva;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = reserva.vuelo;
    return Semantics(
      button: true,
      label: 'Reserva ${reserva.numero}, ${v.origen} a ${v.destino}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
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
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      EtiquetaEstadoReserva(reserva: reserva),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${v.origen} → ${v.destino}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 3),
                            Text(
                              '${Formatos.fecha(v.fecha)} · Salida ${Formatos.hora(v.horaSalida)}',
                              style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
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
                            const Text('Total reserva', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                Formatos.dinero(reserva.totalCentavos),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: reserva.cancelada ? AppColors.textoSuave : const Color(0xFF0F172A),
                                  decoration: reserva.cancelada ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  Row(
                    children: [
                      const Icon(Icons.event_seat_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reserva.cantidad == 1 ? '1 asiento' : '${reserva.cantidad} asientos',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.azul,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onTap,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Ver detalle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
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
