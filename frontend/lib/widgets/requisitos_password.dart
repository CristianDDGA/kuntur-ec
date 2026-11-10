import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/validadores.dart';

/// Lista de requisitos de la contraseña que se va marcando mientras el usuario escribe.
class RequisitosPassword extends StatelessWidget {
  const RequisitosPassword({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final r = Validadores.requisitosPassword(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Requisito(cumplido: r.largo, texto: 'Al menos ${Validadores.passwordMin} caracteres'),
        _Requisito(cumplido: r.letra, texto: 'Incluye letras'),
        _Requisito(cumplido: r.numero, texto: 'Incluye números'),
      ],
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
            Icon(cumplido ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
            const SizedBox(width: 8),
            Text(texto, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
