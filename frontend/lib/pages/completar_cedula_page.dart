import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../controllers/completar_cedula_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/fallo.dart';
import '../models/validadores.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/panel_autenticacion.dart';

/// «Complete su perfil» (V): verifica nombre/correo y registra la cédula obligatoria.
/// Oculta "Volver al inicio" para evitar bucles de redirección; ofrece "Cerrar sesión" como salida clara.
class CompletarCedulaPage extends ConsumerStatefulWidget {
  const CompletarCedulaPage({super.key});

  @override
  ConsumerState<CompletarCedulaPage> createState() => _CompletarCedulaPageState();
}

class _CompletarCedulaPageState extends ConsumerState<CompletarCedulaPage> {
  final _formulario = GlobalKey<FormState>();
  final _cedula = TextEditingController();
  late final TextEditingController _nombre;
  late final TextEditingController _correo;

  @override
  void initState() {
    super.initState();
    final usuario = ref.read(sesionControllerProvider).value;
    _nombre = TextEditingController(text: usuario?.nombre ?? '');
    _correo = TextEditingController(text: usuario?.correo ?? '');
  }

  @override
  void dispose() {
    _cedula.dispose();
    _nombre.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final usuario = ref.read(sesionControllerProvider).value;
    final nombreEditado = _nombre.text.trim();
    final cambioNombre = usuario != null && nombreEditado != usuario.nombre;

    await ref.read(completarCedulaControllerProvider.notifier).guardar(
          _cedula.text,
          nombre: cambioNombre ? nombreEditado : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(sesionControllerProvider).value;
    final estado = ref.watch(completarCedulaControllerProvider);
    final guardando = estado.isLoading;
    final error = estado.hasError && !guardando ? mensajeDeError(estado.error!) : null;

    return PanelAutenticacion(
      titulo: 'Complete su perfil',
      subtitulo: 'Hola${usuario == null ? '' : ', ${usuario.nombre.split(' ').first}'}. '
          'Verifique o edite sus datos y registre su cédula para emitir reservas y pasajes a su nombre.',
      mostrarVolver: false,
      child: AutofillGroup(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nombre,
                enabled: !guardando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                inputFormatters: Validadores.entradaNombre(Validadores.nombreMax),
                validator: Validadores.nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre y apellido',
                  helperText: 'Cargado de Google (puede editarlo si desea corregirlo)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _correo,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico verificado',
                  helperText: 'Cuenta de Google verificada',
                  fillColor: AppColors.superficieSutil,
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
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
                  helperText: '10 dígitos con código verificador oficial (módulo 10).',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AvisoInline(texto: error),
              ],
              const SizedBox(height: 22),
              BotonDegradado(texto: 'Guardar y continuar', cargando: guardando, onPressed: _guardar),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textoSecundario,
                  side: const BorderSide(color: AppColors.borde),
                  minimumSize: const Size(44, 46),
                ),
                onPressed: guardando ? null : () => ref.read(sesionControllerProvider.notifier).cerrarSesion(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
