import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import '../models/validadores.dart';
import 'liquid_morph.dart';

/// Lista de requisitos de la contraseña que se marca en vivo mientras el usuario escribe.
///
/// Usa escala física desde `0.92 → 1.0` + opacidad (`140 ms`, nunca `scale(0)`).
class RequisitosPassword extends StatelessWidget {
  const RequisitosPassword({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final r = Validadores.requisitosPassword(password);
    final cumplidos = [r.largo, r.letra, r.numero].where((c) => c).length;
    return Semantics(
      container: true,
      label: 'Requisitos de la contraseña: $cumplidos de 3 cumplidos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraLiquidMorph(valor: cumplidos / 3, alto: 5),
          const SizedBox(height: 8),
          _Requisito(cumplido: r.largo, texto: 'Al menos ${Validadores.passwordMin} caracteres'),
          _Requisito(cumplido: r.letra, texto: 'Incluye letras'),
          _Requisito(cumplido: r.numero, texto: 'Incluye números'),
        ],
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito({required this.cumplido, required this.texto});

  final bool cumplido;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final color = cumplido ? AppColors.exito : AppColors.textoSuave;
    final duracion = AppMotion.duracion(context, const Duration(milliseconds: 140));
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        label: '$texto: ${cumplido ? 'cumplido' : 'pendiente'}',
        excludeSemantics: true,
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: duracion,
              switchInCurve: AppMotion.curvaSalidaFuerte,
              transitionBuilder: (hijo, animacion) => FadeTransition(
                opacity: animacion,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(animacion),
                  child: hijo,
                ),
              ),
              child: Icon(
                cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(cumplido),
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.opacidadDe(context),
                style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
                child: Text(texto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
