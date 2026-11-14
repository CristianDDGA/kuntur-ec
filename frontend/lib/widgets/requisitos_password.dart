import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';
import '../models/validadores.dart';

/// Lista de requisitos de la contraseña que se va marcando mientras el usuario escribe.
///
/// Añade una barra de progreso animada y cambia el icono de cada requisito con una
/// transición corta, para que el avance se sienta inmediato sin depender solo del color.
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: cumplidos / 3),
            duration: AppMotion.mediaDe(context),
            curve: AppMotion.curvaEntrada,
            builder: (context, valor, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: valor,
                minHeight: 5,
                backgroundColor: AppColors.divisor,
                color: valor >= 1 ? AppColors.exito : AppColors.azul,
              ),
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        label: '$texto: ${cumplido ? 'cumplido' : 'pendiente'}',
        excludeSemantics: true,
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: AppMotion.rapidaDe(context),
              transitionBuilder: (hijo, animacion) => ScaleTransition(scale: animacion, child: hijo),
              child: Icon(
                cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(cumplido),
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: AppMotion.rapidaDe(context),
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
              child: Text(texto),
            ),
          ],
        ),
      ),
    );
  }
}
