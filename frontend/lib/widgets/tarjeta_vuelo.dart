import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import '../models/vuelo.dart';
import 'etiqueta_asientos.dart';
import 'isometric_kuntur.dart';

/// Un vuelo en la lista: ruta, horario, precio tabular y disponibilidad.
///
/// Unificado con `AppColors` y `AppDecorations.tarjeta` (contraste >= 5.19:1),
/// compresión táctil GPU (`scale 0.985`) y semántica de botón único sin duplicados anidados.
class TarjetaVuelo extends StatefulWidget {
  const TarjetaVuelo({super.key, required this.vuelo, required this.onTap});

  final Vuelo vuelo;
  final VoidCallback onTap;

  @override
  State<TarjetaVuelo> createState() => _TarjetaVueloState();
}

class _TarjetaVueloState extends State<TarjetaVuelo> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final vuelo = widget.vuelo;
    return Semantics(
      button: true,
      label: 'Vuelo ${vuelo.codigo} de ${vuelo.origen} a ${vuelo.destino}, ${Formatos.dinero(vuelo.precioCentavos)}',
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
              onHighlightChanged: (v) {
                if (_presionado != v) setState(() => _presionado = v);
              },
              hoverColor: AppColors.infoSuave.withValues(alpha: 0.45),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cuerpo.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTextStyles.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        EtiquetaAsientos(vuelo: vuelo),
                      ],
                    ),
                    const SizedBox(height: 14),
                    RutaVuelo(vuelo: vuelo),
                    const Divider(height: 24, color: AppColors.divisor),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final esEstrecho = constraints.maxWidth < 540;
                        final precio = Text(
                          Formatos.dinero(vuelo.precioCentavos),
                          softWrap: false,
                          style: AppTextStyles.moneda.copyWith(fontSize: 22),
                        );

                        if (esEstrecho) {
                          return Row(
                            children: [
                              const Expanded(
                                child: Text('Por persona', style: AppTextStyles.nota),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: precio,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            const Icon(Icons.luggage_outlined, size: 16, color: AppColors.textoSecundario),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Equipaje de mano incluido',
                                style: AppTextStyles.nota,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Por persona', style: AppTextStyles.nota),
                            const SizedBox(width: 10),
                            Flexible(
                              flex: 0,
                              child: FittedBox(fit: BoxFit.scaleDown, child: precio),
                            ),
                            const SizedBox(width: 14),
                            // Acción visual integrada (la tarjeta completa posee el Semantics/onTap único).
                            ExcludeSemantics(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.azul,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Seleccionar',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
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
      ),
    );
  }
}

/// Código del vuelo en una pastilla azul con numerales tabulares.
class CodigoVuelo extends StatelessWidget {
  const CodigoVuelo(this.codigo, {super.key});

  final String codigo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(8)),
        child: Text(
          codigo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            fontFeatures: AppTextStyles.tabular,
          ),
        ),
      );
}

/// "08:00 Quito ——✈—— 08:45 Esmeraldas", con la duración encima del arco.
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
                  Text(
                    Formatos.duracion(vuelo.duracion),
                    style: AppTextStyles.nota.copyWith(fontFeatures: AppTextStyles.tabular),
                  ),
                  const ArcoVueloIsometrico(alto: 44),
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
          constraints: const BoxConstraints(maxWidth: 136),
          child: Column(
            crossAxisAlignment: alinear,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hora,
                  style: AppTextStyles.subtitulo.copyWith(
                    fontSize: 22,
                    fontFeatures: AppTextStyles.tabular,
                  ),
                ),
              ),
              Tooltip(
                message: ciudad,
                child: Text(
                  ciudad,
                  style: AppTextStyles.cuerpo,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
}
