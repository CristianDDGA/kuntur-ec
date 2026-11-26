import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import 'isometric_kuntur.dart';

enum EstadoAsiento { libre, seleccionado, ocupado }

/// Un asiento del mapa: libre (blanco), seleccionado (azul) u ocupado (rojo, inactivo).
///
/// Área táctil mínima de 44×44 pt y compresión física GPU (`scale 0.95`) al presionar.
class AsientoBoton extends StatefulWidget {
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

  /// Se ve más tenue cuando ya se alcanzó el máximo de asientos y este no está elegido.
  final bool atenuado;

  /// Lado del área táctil en puntos lógicos (44–48 según el ancho disponible).
  final double lado;

  @override
  State<AsientoBoton> createState() => _AsientoBotonState();
}

class _AsientoBotonState extends State<AsientoBoton> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.estado != EstadoAsiento.ocupado;
    final (fondo, borde, texto) = switch (widget.estado) {
      EstadoAsiento.libre => (AppColors.superficie, AppColors.azul, AppColors.azul),
      EstadoAsiento.seleccionado => (AppColors.azul, AppColors.azul, Colors.white),
      EstadoAsiento.ocupado => (AppColors.errorSuave, AppColors.error.withValues(alpha: 0.5), AppColors.error),
    };
    final descripcion = switch (widget.estado) {
      EstadoAsiento.libre => 'disponible',
      EstadoAsiento.seleccionado => 'seleccionado',
      EstadoAsiento.ocupado => 'ocupado',
    };

    return Semantics(
      button: habilitado,
      selected: widget.estado == EstadoAsiento.seleccionado,
      enabled: habilitado,
      label: 'Asiento ${widget.numero}, $descripcion',
      onTap: habilitado ? widget.onTap : null,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado && habilitado ? 0.94 : 1.0,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: SizedBox(
          width: widget.lado,
          height: widget.lado,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.lado * 0.26),
              onTap: habilitado ? widget.onTap : null,
              onHighlightChanged: (v) {
                if (_presionado != v) setState(() => _presionado = v);
              },
              hoverColor: habilitado ? AppColors.azul.withValues(alpha: 0.08) : Colors.transparent,
              child: Padding(
                padding: EdgeInsets.all(widget.lado * 0.09),
                child: AsientoIsometrico3D(
                  numero: widget.numero,
                  fondo: fondo,
                  borde: borde,
                  texto: texto,
                  seleccionado: widget.estado == EstadoAsiento.seleccionado,
                  ocupado: widget.estado == EstadoAsiento.ocupado,
                  atenuado: widget.atenuado,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
