import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';

/// Un tramo del camino: "Mis reservas" (con [ruta], se puede tocar) o "KEC-0058" (el último, sin [ruta]).
class Miga {
  const Miga(this.texto, {this.ruta});

  final String texto;
  final String? ruta;
}

/// Migas de pan: "Vuelos › KT101 › Elegir asientos". Muestran dónde está el usuario y permiten
/// volver a cualquier nivel anterior con un toque.
class Migas extends StatelessWidget {
  const Migas(this.items, {super.key});

  final List<Miga> items;

  @override
  Widget build(BuildContext context) {
    final tramos = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final miga = items[i];
      final ultima = i == items.length - 1;
      if (i > 0) {
        tramos.add(const Icon(Icons.chevron_right, size: 18, color: AppColors.textoSuave));
      }
      tramos.add(
        ultima || miga.ruta == null
            ? Text(miga.texto, style: AppTextStyles.nota.copyWith(fontWeight: FontWeight.w800, color: AppColors.textoPrincipal))
            : Semantics(
                button: true,
                label: 'Ir a ${miga.texto}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.go(miga.ruta!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      miga.texto,
                      style: AppTextStyles.nota.copyWith(color: AppColors.azul, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ),
      );
    }
    return Semantics(
      container: true,
      label: 'Ruta de navegación',
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 0, children: tramos),
    );
  }
}
