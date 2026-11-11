import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/vuelo.dart';
import 'etiqueta_asientos.dart';

/// Un vuelo en la lista: ruta, horario, precio y disponibilidad.
class TarjetaVuelo extends StatelessWidget {
  const TarjetaVuelo({super.key, required this.vuelo, required this.onTap});

  final Vuelo vuelo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vuelo ${vuelo.codigo} de ${vuelo.origen} a ${vuelo.destino}',
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
                      CodigoVuelo(vuelo.codigo),
                      const SizedBox(width: 10),
                      Expanded(child: Text(Formatos.fecha(vuelo.fecha), style: AppTextStyles.cuerpo)),
                      EtiquetaAsientos(vuelo: vuelo),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RutaVuelo(vuelo: vuelo),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Por persona', style: AppTextStyles.nota),
                      const Spacer(),
                      Text(
                        Formatos.dinero(vuelo.precioCentavos),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul),
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

/// Código del vuelo en una pastilla azul.
class CodigoVuelo extends StatelessWidget {
  const CodigoVuelo(this.codigo, {super.key});

  final String codigo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(8)),
        child: Text(
          codigo,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      );
}

/// "08:00 Quito ——✈—— 08:45 Esmeraldas", con la duración encima de la línea.
class RutaVuelo extends StatelessWidget {
  const RutaVuelo({super.key, required this.vuelo});

  final Vuelo vuelo;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Extremo(hora: Formatos.hora(vuelo.horaSalida), ciudad: vuelo.origen, alinear: CrossAxisAlignment.start),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Text(Formatos.duracion(vuelo.duracion), style: AppTextStyles.nota),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.borde, thickness: 1.5)),
                      Icon(Icons.flight, size: 18, color: AppColors.azul),
                      Expanded(child: Divider(color: AppColors.borde, thickness: 1.5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _Extremo(hora: Formatos.hora(vuelo.horaLlegada), ciudad: vuelo.destino, alinear: CrossAxisAlignment.end),
        ],
      );
}

class _Extremo extends StatelessWidget {
  const _Extremo({required this.hora, required this.ciudad, required this.alinear});

  final String hora;
  final String ciudad;
  final CrossAxisAlignment alinear;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Column(
          crossAxisAlignment: alinear,
          children: [
            Text(hora, style: AppTextStyles.subtitulo.copyWith(fontSize: 22)),
            Text(ciudad, style: AppTextStyles.cuerpo, overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      );
}
