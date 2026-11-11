import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../models/asientos.dart';
import '../models/vuelo.dart';
import 'aviso.dart';
import 'boton_degradado.dart';

/// "Reservar este vuelo": lleva al mapa para elegir los asientos. Si el vuelo está agotado, lo explica.
class PanelReserva extends StatelessWidget {
  const PanelReserva({super.key, required this.vuelo});

  final Vuelo vuelo;

  @override
  Widget build(BuildContext context) {
    if (vuelo.agotado) {
      return const AvisoInline(texto: 'Este vuelo ya no tiene asientos disponibles.');
    }
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Reservar este vuelo', style: AppTextStyles.subtitulo),
          const SizedBox(height: 6),
          const Text(
            'Elija en el mapa del avión los asientos que quiere (hasta ${SeleccionAsientos.maximo} por reserva). '
            'Verá el total antes de confirmar.',
            style: AppTextStyles.cuerpo,
          ),
          const SizedBox(height: 16),
          BotonDegradado(
            texto: 'Elegir asientos',
            onPressed: () => context.push(AppRoutes.asientosDelVuelo(vuelo.id)),
          ),
        ],
      ),
    );
  }
}
