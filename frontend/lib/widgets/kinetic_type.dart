import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Motores de **tipografía cinética** de Kuntur EC.
///
/// Todas las animaciones son FINITAS, se reinician por clave cuando cambia el
/// texto y respetan Reduce Motion vía [AppMotion]. Cada widget deja **un solo
/// `Text` en el árbol** (`Opacity`/`Transform` no crean nodos de texto), de modo
/// que `find.text(...)` de la suite sigue encontrando exactamente un resultado.

/// Encabezado con revelado escalonado: fundido, deslizamiento vertical de 10 px
/// y asentamiento del interletrado (`1.2 → -0.4`) al entrar o cambiar de texto.
class TituloCinetico extends StatelessWidget {
  const TituloCinetico(
    this.texto, {
    super.key,
    this.estilo,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String texto;
  final TextStyle? estilo;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = estilo ?? AppTextStyles.titulo;
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(texto),
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.heroeDe(context),
      curve: AppMotion.curvaEntrada,
      builder: (context, avance, _) => Opacity(
        opacity: avance.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - avance) * 10),
          child: Text(
            texto,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: base.copyWith(letterSpacing: 1.2 - 1.6 * avance),
          ),
        ),
      ),
    );
  }
}

/// Marcador numérico con respuesta cinética (montos, porcentajes, contadores).
///
/// Al cambiar [texto], el valor entra con un pulso corto de opacidad y
/// desplazamiento vertical. Un único `Text` conserva la compatibilidad con
/// `find.text(r'$86.83')`.
class OdometroCinetico extends StatelessWidget {
  const OdometroCinetico({
    super.key,
    required this.texto,
    this.estilo,
    this.prefijo = '',
    this.sufijo = '',
    this.textAlign,
  });

  final String texto;
  final TextStyle? estilo;
  final String prefijo;
  final String sufijo;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => _Revelar(
        inicio: 0.92,
        desplazamiento: const Offset(0, 8),
        duracion: AppMotion.mediaDe,
        child: Text('$prefijo$texto$sufijo', textAlign: textAlign, style: estilo),
      );
}

/// Ruta `origen → destino` que se reacomoda con una entrada lateral corta
/// (usada al intercambiar el rumbo y en la vista previa del vuelo).
class TextoRutaCinetica extends StatelessWidget {
  const TextoRutaCinetica({
    super.key,
    required this.origen,
    required this.destino,
    this.estilo,
    this.separador = '→',
    this.textAlign,
  });

  final String origen;
  final String destino;
  final TextStyle? estilo;
  final String separador;
  final TextAlign? textAlign;

  String get _texto {
    final desde = origen.trim().isEmpty ? 'Origen' : origen.trim();
    final hacia = destino.trim().isEmpty ? 'Destino' : destino.trim();
    return '$desde $separador $hacia';
  }

  @override
  Widget build(BuildContext context) => _Revelar(
        inicio: 0,
        desplazamiento: const Offset(12, 0),
        duracion: AppMotion.mediaDe,
        child: Text(_texto, textAlign: textAlign, style: estilo),
      );
}

/// Fundido + desplazamiento finito compartido por los textos cinéticos.
///
/// Un único `Text` dentro del `Opacity`/`Transform` mantiene los `find.text`
/// de la suite funcionando mientras la animación corre.
class _Revelar extends StatelessWidget {
  const _Revelar({
    required this.inicio,
    required this.desplazamiento,
    required this.duracion,
    required this.child,
  });

  final double inicio;
  final Offset desplazamiento;
  final Duration Function(BuildContext) duracion;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey<Widget>(child),
        tween: Tween<double>(begin: inicio, end: 1),
        duration: duracion(context),
        curve: AppMotion.curvaEntrada,
        builder: (context, avance, hijo) => Opacity(
          opacity: avance.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(
              desplazamiento.dx * (1 - avance),
              desplazamiento.dy * (1 - avance),
            ),
            child: hijo,
          ),
        ),
        child: child,
      );
}
