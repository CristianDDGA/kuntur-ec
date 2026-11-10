import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/validadores.dart';

/// Campo de contraseña con botón para mostrar u ocultar lo escrito.
class CampoPassword extends StatefulWidget {
  const CampoPassword({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _oculta,
        enabled: widget.enabled,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        enableSuggestions: false,
        autocorrect: false,
        inputFormatters: [LengthLimitingTextInputFormatter(Validadores.passwordMax)],
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _oculta = !_oculta),
          ),
        ),
      );
}
