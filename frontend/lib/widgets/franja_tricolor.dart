import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Franja fina con los colores de la bandera del Ecuador en su proporción real
/// (amarillo el doble de ancho que el azul y el rojo). Es el único adorno de marca.
class FranjaTricolor extends StatelessWidget {
  const FranjaTricolor({super.key, this.alto = 5});

  final double alto;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: alto,
          child: const Row(
            children: [
              Expanded(flex: 2, child: ColoredBox(color: AppColors.amarillo, child: SizedBox.expand())),
              Expanded(child: ColoredBox(color: AppColors.azul, child: SizedBox.expand())),
              Expanded(child: ColoredBox(color: AppColors.rojo, child: SizedBox.expand())),
            ],
          ),
        ),
      );
}
