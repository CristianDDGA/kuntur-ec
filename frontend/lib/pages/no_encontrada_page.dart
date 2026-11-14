import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../widgets/estado_vista.dart';
import '../widgets/kuntur_scaffold.dart';

/// Se muestra cuando alguien escribe una dirección que no existe (por ejemplo `/#/algo-raro`).
class NoEncontradaPage extends StatelessWidget {
  const NoEncontradaPage({super.key});

  @override
  Widget build(BuildContext context) => KunturScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: VacioVista(
              icono: Icons.explore_off_outlined,
              titulo: 'No encontramos esa página',
              mensaje: 'Puede que la dirección esté mal escrita.',
              textoAccion: 'Ir al inicio',
              onAccion: () => context.go(AppRoutes.inicio),
            ),
          ),
        ),
      );
}
