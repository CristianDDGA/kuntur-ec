import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum EstadoAsiento { libre, seleccionado, ocupado }

/// Un asiento del mapa. Libre (blanco), seleccionado (azul) u ocupado (rojo, no se puede tocar).
class AsientoBoton extends StatelessWidget {
  const AsientoBoton({
    super.key,
    required this.numero,
    required this.estado,
    required this.onTap,
    this.atenuado = false,
  });

  static const double tamano = 44;

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
      excludeSemantics: true,
      child: Opacity(
        opacity: atenuado ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: fondo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: borde, width: estado == EstadoAsiento.libre ? 1.5 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: estado == EstadoAsiento.ocupado ? null : onTap,
              child: SizedBox(
                width: tamano - 6,
                height: tamano - 6,
                child: Center(
                  child: estado == EstadoAsiento.ocupado
                      ? Icon(Icons.close, size: 18, color: texto)
                      : Text(numero, style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
