import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Un tramo del camino: "Mis reservas" (con [ruta], interactivo) o el destino actual (sin [ruta]).
class Miga {
  const Miga(this.texto, {this.ruta, this.etiquetaSemantica});

  final String texto;
  final String? ruta;

  /// Descripción opcional más clara para lectores de pantalla y pruebas semánticas.
  final String? etiquetaSemantica;
}

/// Migas de pan táctiles: cada tramo navegable se presenta como un control tipo pastilla
/// con superficie definida, borde fino, foco visible y compresión GPU (`scale 0.97`),
/// diferenciándose claramente de hipervínculos planos o etiquetas estáticas.
class Migas extends StatelessWidget {
  const Migas(this.items, {super.key, this.onInterceptar});

  final List<Miga> items;

  /// Si se provee (p. ej. formularios o cabina con cambios sin guardar), se invoca antes de navegar
  /// a [ruta] y permite pedir confirmación en lugar de desactivar silenciosamente las migas.
  final void Function(String ruta)? onInterceptar;

  @override
  Widget build(BuildContext context) {
    final tramos = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final miga = items[i];
      final ultima = i == items.length - 1;
      if (i > 0) {
        tramos.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textoSuave),
          ),
        );
      }
      if (ultima) {
        tramos.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              miga.texto,
              style: AppTextStyles.nota.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textoPrincipal,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        );
      } else if (miga.ruta == null) {
        tramos.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              miga.texto,
              style: AppTextStyles.nota.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textoSuave,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        );
      } else {
        final ruta = miga.ruta!;
        tramos.add(
          _PastillaMiga(
            texto: miga.texto,
            etiqueta: miga.etiquetaSemantica ?? 'Ir a ${miga.texto}',
            esRaiz: i == 0,
            onTap: () => onInterceptar != null ? onInterceptar!(ruta) : context.go(ruta),
          ),
        );
      }
    }
    return Semantics(
      container: true,
      label: 'Ruta de navegación',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 6,
        children: tramos,
      ),
    );
  }
}

class _PastillaMiga extends StatefulWidget {
  const _PastillaMiga({
    required this.texto,
    required this.etiqueta,
    required this.esRaiz,
    required this.onTap,
  });

  final String texto;
  final String etiqueta;
  final bool esRaiz;
  final VoidCallback onTap;

  @override
  State<_PastillaMiga> createState() => _PastillaMigaState();
}

class _PastillaMigaState extends State<_PastillaMiga> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.etiqueta,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1.0,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: Material(
          color: AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.borde.withValues(alpha: 0.95)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) {
              if (_presionado != v) setState(() => _presionado = v);
            },
            hoverColor: AppColors.infoSuave,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.esRaiz) ...[
                      const Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.azul),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      widget.texto,
                      style: AppTextStyles.nota.copyWith(
                        fontSize: 13,
                        color: AppColors.azul,
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
