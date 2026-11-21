import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/vuelo.dart';
import 'etiqueta_asientos.dart';
import 'isometric_kuntur.dart';
import 'kinetic_type.dart';

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
                      CodigoVuelo(vuelo.codigo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          Formatos.fecha(vuelo.fecha),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      EtiquetaAsientos(vuelo: vuelo),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RutaVuelo(vuelo: vuelo),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final esEstrecho = constraints.maxWidth < 540;
                      if (esEstrecho) {
                        return Row(
                          children: [
                            const Expanded(child: Text('Por persona', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: OdometroCinetico(
                                  texto: Formatos.dinero(vuelo.precioCentavos),
                                  estilo: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Icon(Icons.luggage_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Equipaje de mano incluido',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Por persona', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: OdometroCinetico(
                                texto: Formatos.dinero(vuelo.precioCentavos),
                                estilo: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.azul,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: onTap,
                            child: const Text('Seleccionar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ],
                      );
                    },
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
                  // Arco de vuelo isométrico 2.5D en lugar del divisor plano.
                  const ArcoVueloIsometrico(alto: 46),
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
  Widget build(BuildContext context) => Flexible(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Column(
            crossAxisAlignment: alinear,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(hora, style: AppTextStyles.subtitulo.copyWith(fontSize: 22)),
              ),
              Text(ciudad, style: AppTextStyles.cuerpo, overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ),
      );
}
