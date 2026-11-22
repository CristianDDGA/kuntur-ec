import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/completar_cedula_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/panel_autenticacion.dart';

/// «Complete su perfil» (V): muestra los datos de la persona (nombre, correo) y solicita la cédula
/// para habilitar la emisión de reservas y facturas legales.
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
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nombre,
              enabled: !guardando,
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
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico verificado',
                helperText: 'Cuenta de Google verificada',
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
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: guardando ? null : () => ref.read(sesionControllerProvider.notifier).cerrarSesion(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
