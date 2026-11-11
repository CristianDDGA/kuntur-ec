import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';

/// Se muestra cuando alguien escribe una dirección que no existe (por ejemplo `/#/algo-raro`).
class NoEncontradaPage extends StatelessWidget {
  const NoEncontradaPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore_off_outlined, size: 56, color: AppColors.textoSuave),
                  const SizedBox(height: 14),
                  const Text('No encontramos esa página', style: AppTextStyles.subtitulo, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('Puede que la dirección esté mal escrita.', style: AppTextStyles.cuerpo, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.inicio),
                    child: const Text('Ir al inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
