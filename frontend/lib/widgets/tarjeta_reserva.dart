import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
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
        decoration: AppDecorations.tarjeta,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CodigoVuelo(v.codigo),
                      const SizedBox(width: 10),
                      Expanded(child: Text(reserva.numero, style: AppTextStyles.nota)),
                      EtiquetaEstadoReserva(reserva: reserva),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${v.origen} → ${v.destino}', style: AppTextStyles.subtitulo),
                  const SizedBox(height: 2),
                  Text(
                    '${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)}',
                    style: AppTextStyles.cuerpo,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.event_seat_outlined, size: 18, color: AppColors.textoSuave),
                      const SizedBox(width: 6),
                      Text(
                        reserva.cantidad == 1 ? '1 asiento' : '${reserva.cantidad} asientos',
                        style: AppTextStyles.cuerpo,
                      ),
                      const Spacer(),
                      Text(
                        Formatos.dinero(reserva.totalCentavos),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: reserva.cancelada ? AppColors.textoSuave : AppColors.azul,
                          decoration: reserva.cancelada ? TextDecoration.lineThrough : null,
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
    );
  }
}

/// "Confirmada", "Cancelada" o "Vuelo realizado".
class EtiquetaEstadoReserva extends StatelessWidget {
  const EtiquetaEstadoReserva({super.key, required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    final (texto, color, fondo) = reserva.cancelada
        ? ('Cancelada', AppColors.error, AppColors.errorSuave)
        : reserva.vuelo.yaPartio()
            ? ('Vuelo realizado', AppColors.textoSecundario, AppColors.divisor)
            : ('Confirmada', AppColors.exito, AppColors.exitoSuave);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}
