import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'isometric_kuntur.dart';

enum EstadoAsiento { libre, seleccionado, ocupado }

/// Un asiento del mapa. Libre (blanco), seleccionado (azul) u ocupado (rojo, no se puede tocar).
///
/// El área táctil completa mide [lado] (por defecto [tamano] = 48 pt, por encima
/// del mínimo de 44 pt de Apple HIG) y el dibujo interior es una butaca
/// isométrica 2.5D ([AsientoIsometrico3D]). La cabina ajusta [lado] entre 44 y 48
/// pt para que 3 butacas + pasillo + 3 butacas entren sin desbordar.
class AsientoBoton extends StatelessWidget {
  const AsientoBoton({
    super.key,
    required this.numero,
    required this.estado,
    required this.onTap,
    this.atenuado = false,
    this.lado = tamano,
  }) : assert(lado >= 44, 'El área táctil del asiento debe cumplir el mínimo HIG de 44 pt.');

  static const double tamano = 48;

  final String numero;
  final EstadoAsiento estado;
  final VoidCallback onTap;

  /// Se ve más tenue (cuando ya se eligió el máximo de asientos y este no está elegido).
  final bool atenuado;

  /// Lado del área táctil en puntos lógicos (44–48 según el ancho disponible).
  final double lado;

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
      child: SizedBox(
        width: lado,
        height: lado,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(lado * 0.26),
            onTap: estado == EstadoAsiento.ocupado ? null : onTap,
            child: Padding(
              padding: EdgeInsets.all(lado * 0.09),
              child: AsientoIsometrico3D(
                numero: numero,
                fondo: fondo,
                borde: borde,
                texto: texto,
                seleccionado: estado == EstadoAsiento.seleccionado,
                ocupado: estado == EstadoAsiento.ocupado,
                atenuado: atenuado,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
