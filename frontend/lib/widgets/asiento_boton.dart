import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

enum EstadoAsiento { libre, seleccionado, ocupado }

/// Un asiento del mapa. Libre (blanco), seleccionado (azul) u ocupado (rojo, no se puede tocar).
///
/// El área táctil completa mide [tamano] (48 pt: por encima del mínimo de 44 pt
/// de Apple HIG) aunque la forma visible del asiento siga siendo compacta: así
/// se toca cómodo en móvil y en web no se rompe la silueta de la cabina.
class AsientoBoton extends StatelessWidget {
  const AsientoBoton({
    super.key,
    required this.numero,
    required this.estado,
    required this.onTap,
    this.atenuado = false,
  });

  static const double tamano = 48;

  final String numero;
  final EstadoAsiento estado;
  final VoidCallback onTap;

  /// Se ve más tenue (cuando ya se eligió el máximo de asientos y este no está elegido).
  final bool atenuado;

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, texto) = switch (estado) {
      EstadoAsiento.libre => (AppColors.superficie, AppColors.azul, AppColors.azul),
      EstadoAsiento.seleccionado => (AppColors.azul, AppColors.azul, Colors.white),
      EstadoAsiento.ocupado => (AppColors.errorSuave, AppColors.error.withValues(alpha: 0.5), AppColors.error),
    };
    final descripcion = switch (estado) {
      EstadoAsiento.libre => 'disponible',
      EstadoAsiento.seleccionado => 'seleccionado',
      EstadoAsiento.ocupado => 'ocupado',
    };
    return Semantics(
      button: estado != EstadoAsiento.ocupado,
      selected: estado == EstadoAsiento.seleccionado,
      enabled: estado != EstadoAsiento.ocupado,
      label: 'Asiento $numero, $descripcion',
      // La acción se declara en el nodo semántico: el InkWell queda excluido.
      onTap: estado == EstadoAsiento.ocupado ? null : onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: atenuado ? 0.45 : 1,
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: estado == EstadoAsiento.ocupado ? null : onTap,
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.rapidaDe(context),
                  curve: AppMotion.curvaTactil,
                  width: tamano - 10,
                  height: tamano - 10,
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borde,
                      width: estado == EstadoAsiento.libre ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: estado == EstadoAsiento.ocupado
                        ? Icon(Icons.close, size: 18, color: texto)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              numero,
                              style: TextStyle(color: texto, fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
