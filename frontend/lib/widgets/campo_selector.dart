import 'package:flutter/material.dart';

/// Campo de formulario que no se escribe: al tocarlo abre un selector (fecha u hora) y
/// muestra el valor elegido. El valor lo guarda el widget padre; el campo solo lo refleja
/// y valida como cualquier otro campo del `Form`.
class CampoSelector<T> extends StatelessWidget {
  const CampoSelector({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    required this.formato,
    required this.elegir,
    required this.alElegir,
    this.validador,
    this.errorEnVivo,
    this.habilitado = true,
  });

  final String etiqueta;
  final IconData icono;
  final T? valor;
  final String Function(T) formato;
  final Future<T?> Function() elegir;
  final ValueChanged<T> alElegir;
  final String? Function(T?)? validador;

  /// Error que se muestra de inmediato (sin esperar a enviar el formulario), por ejemplo
  /// "esa hora ya pasó" apenas el usuario la elige.
  final String? errorEnVivo;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      // La clave por valor hace que el campo se reconstruya (y se revalide) al cambiar.
      key: ValueKey((valor, errorEnVivo)),
      initialValue: valor,
      validator: validador,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (estado) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: habilitado
            ? () async {
                final elegido = await elegir();
                if (elegido != null) alElegir(elegido);
              }
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiqueta,
            prefixIcon: Icon(icono),
            errorText: errorEnVivo ?? estado.errorText,
          ),
          isEmpty: valor == null,
          child: Text(valor == null ? '' : formato(valor as T), style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
