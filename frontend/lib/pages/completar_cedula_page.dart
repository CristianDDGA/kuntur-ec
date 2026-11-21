import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/completar_cedula_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/panel_autenticacion.dart';

/// «Complete su perfil» (V): pide la cédula a los clientes que no la tienen (p. ej. los que entraron con Google).
/// El router no deja pasar a otra pantalla hasta que se guarda. Es la misma validación y unicidad del registro.
class CompletarCedulaPage extends ConsumerStatefulWidget {
  const CompletarCedulaPage({super.key});

  @override
  ConsumerState<CompletarCedulaPage> createState() => _CompletarCedulaPageState();
}

class _CompletarCedulaPageState extends ConsumerState<CompletarCedulaPage> {
  final _formulario = GlobalKey<FormState>();
  final _cedula = TextEditingController();

  @override
  void dispose() {
    _cedula.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(completarCedulaControllerProvider.notifier).guardar(_cedula.text);
    // Si se guardó, la sesión ya tiene la cédula y el router lleva a la lista de vuelos.
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(sesionControllerProvider).value;
    final estado = ref.watch(completarCedulaControllerProvider);
    final guardando = estado.isLoading;
    final error = estado.hasError && !guardando ? mensajeDeError(estado.error!) : null;

    return PanelAutenticacion(
      titulo: 'Complete su perfil',
      subtitulo: 'Hola${usuario == null ? '' : ', ${usuario.nombre.split(' ').first}'}. Para reservar necesitamos su '
          'número de cédula. Solo se pide una vez y no se puede cambiar después.',
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _cedula,
              enabled: !guardando,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _guardar(),
              validator: Validadores.cedula,
              inputFormatters: Validadores.entradaCedula,
              decoration: const InputDecoration(
                labelText: 'Cédula de identidad',
                helperText: '10 dígitos. Se valida el número, no se consulta ningún registro.',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AvisoInline(texto: error),
            ],
            const SizedBox(height: 20),
            BotonDegradado(texto: 'Guardar y continuar', cargando: guardando, onPressed: _guardar),
            const SizedBox(height: 8),
            TextButton(
              onPressed: guardando ? null : () => ref.read(sesionControllerProvider.notifier).cerrarSesion(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
