import 'package:flutter/material.dart';

import '../config/app_motion.dart';
import '../config/app_theme.dart';

/// Motores de **tipografía cinética** de Kuntur EC.
///
/// Todas las animaciones operan exclusivamente en GPU (`Opacity` y `Transform.translate`),
/// sin animar propiedades de layout como `letterSpacing`, y respetan Reduce Motion
/// vía [AppMotion]. Cada widget deja **un solo `Text` en el árbol** para compatibilidad
/// directa con lectores de pantalla y `find.text(...)`.

/// Encabezado con revelado corto de opacidad y traslación vertical (`6 px`, solo GPU).
/// Reservado para superficies de marca/entrada; las pantallas operativas usan `Text` directo.
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
    return _RevelarTexto(
      clave: texto,
      desplazamiento: const Offset(0, 6),
      duracion: AppMotion.mediaDe,
      child: Text(
        texto,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: base,
      ),
    );
  }
}

/// Marcador numérico reactivo con numerales tabulares garantizados (montos y porcentajes en vivo).
///
/// Al cambiar [texto], el valor entra con un pulso GPU corto (`160 ms`) sin cambiar el ancho
/// de los dígitos. Un único `Text` conserva `find.text(r'$ 86.83')`.
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
  Widget build(BuildContext context) {
    final completo = '$prefijo$texto$sufijo';
    final estiloTabular = (estilo ?? AppTextStyles.moneda).copyWith(
      fontFeatures: AppTextStyles.tabular,
    );
    return _RevelarTexto(
      clave: completo,
      desplazamiento: const Offset(0, 5),
      duracion: AppMotion.rapidaDe,
      child: Text(
        completo,
        textAlign: textAlign,
        softWrap: false,
        style: estiloTabular,
      ),
    );
  }
}

/// Ruta `origen → destino` que se reacomoda con una entrada lateral corta al cambiar la ruta.
class TextoRutaCinetica extends StatelessWidget {
  const TextoRutaCinetica({
    super.key,
    required this.origen,
    required this.destino,
    this.estilo,
    this.separador = '→',
    this.textAlign,
    this.maxLines = 2,
  });

  final String origen;
  final String destino;
  final TextStyle? estilo;
  final String separador;
  final TextAlign? textAlign;
  final int? maxLines;

  String get _texto {
    final desde = origen.trim().isEmpty ? 'Origen' : origen.trim();
    final hacia = destino.trim().isEmpty ? 'Destino' : destino.trim();
    return '$desde $separador $hacia';
  }

  @override
  Widget build(BuildContext context) => _RevelarTexto(
        clave: _texto,
        desplazamiento: const Offset(8, 0),
        duracion: AppMotion.rapidaDe,
        child: Text(
          _texto,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
          style: estilo,
        ),
      );
}

/// Fundido + desplazamiento finito claveado por valor de texto (nunca por instancia `Widget`),
/// evitando que rebuilds no relacionados vuelvan a disparar la animación.
class _RevelarTexto extends StatelessWidget {
  const _RevelarTexto({
    required this.clave,
    required this.desplazamiento,
    required this.duracion,
    required this.child,
  });

  final String clave;
  final Offset desplazamiento;
  final Duration Function(BuildContext) duracion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducido = AppMotion.movimientoReducido(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(clave),
      tween: Tween<double>(begin: 0, end: 1),
      duration: reducido ? Duration.zero : duracion(context),
      curve: AppMotion.curvaSalidaFuerte,
      builder: (context, avance, hijo) => Opacity(
        opacity: (0.25 + 0.75 * avance).clamp(0.0, 1.0),
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
}
