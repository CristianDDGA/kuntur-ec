import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/registro_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_password.dart';
import '../widgets/panel_autenticacion.dart';
import '../widgets/requisitos_password.dart';

/// Vista (V de MVC) del registro. Valida cada campo con las mismas reglas que el servidor.
class RegistroPage extends ConsumerStatefulWidget {
  const RegistroPage({super.key});

  @override
  ConsumerState<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends ConsumerState<RegistroPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(registroControllerProvider.notifier).registrar(
          nombre: _nombre.text,
          correo: _correo.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(registroControllerProvider);
    final cargando = estado.isLoading;
    final error = estado.hasError && !cargando ? mensajeDeError(estado.error!) : null;

    return PanelAutenticacion(
      titulo: 'Cree su cuenta',
      subtitulo: 'Solo le tomará un minuto. Con ella podrá reservar vuelos por todo el país.',
      child: AutofillGroup(
        child: Form(
          key: _formulario,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombre,
                enabled: !cargando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validadores.nombre,
                inputFormatters: [LengthLimitingTextInputFormatter(Validadores.nombreMax)],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _correo,
                enabled: !cargando,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validadores.correo,
                inputFormatters: [LengthLimitingTextInputFormatter(Validadores.correoMax)],
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 16),
              CampoPassword(
                controller: _password,
                label: 'Contraseña',
                enabled: !cargando,
                validator: Validadores.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}), // actualiza la lista de requisitos
              ),
              const SizedBox(height: 8),
              RequisitosPassword(password: _password.text),
              const SizedBox(height: 16),
              CampoPassword(
                controller: _confirmacion,
                label: 'Repita la contraseña',
                enabled: !cargando,
                validator: Validadores.confirmacion(() => _password.text),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _enviar(),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                AvisoInline(texto: error),
              ],
              const SizedBox(height: 24),
              BotonDegradado(texto: 'Crear cuenta', cargando: cargando, onPressed: _enviar),
              const SizedBox(height: 12),
              // Wrap: si no cabe en una línea (pantallas angostas) el enlace baja a la siguiente.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿Ya tiene una cuenta?'),
                  TextButton(
                    onPressed: cargando ? null : () => context.go(AppRoutes.login),
                    child: const Text('Inicie sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
