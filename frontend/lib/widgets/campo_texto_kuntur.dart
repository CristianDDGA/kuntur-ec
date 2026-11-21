import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto de Kuntur EC con el botón "Limpiar" integrado.
///
/// Reemplaza los sufijos `_botonLimpiar` que se repetían en los formularios y
/// mantiene las etiquetas y validadores que esperan las pruebas.
class CampoTextoKuntur extends StatelessWidget {
  const CampoTextoKuntur({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.icono,
    this.validador,
    this.inputFormatters,
    this.textInputAction,
    this.onEnviado,
    this.mostrarLimpiar = false,
    this.enabled = true,
    this.hint,
    this.ayuda,
    this.tipoTeclado,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final IconData? icono;
  final String? Function(String?)? validador;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onEnviado;

  /// Muestra un botón para vaciar el campo cuando tiene texto.
  final bool mostrarLimpiar;
  final bool enabled;

  /// Texto de ejemplo dentro del campo.
  final String? hint;

  /// Texto de ayuda debajo del campo.
  final String? ayuda;

  /// Tipo de teclado (numérico, decimal, etc.).
  final TextInputType? tipoTeclado;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controlador,
        builder: (context, valor, _) => TextFormField(
          controller: controlador,
          enabled: enabled,
          keyboardType: tipoTeclado,
          validator: validador,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onFieldSubmitted: onEnviado,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: etiqueta,
            hintText: hint,
            helperText: ayuda,
            prefixIcon: icono == null ? null : Icon(icono),
            suffixIcon: mostrarLimpiar && valor.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Borrar',
                    onPressed: controlador.clear,
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
        ),
      );
}
