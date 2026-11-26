import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/registro_controller.dart';
import '../models/fallo.dart';
import '../models/validadores.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/boton_google.dart';
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
  final _cedula = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _correo.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final creada = await ref.read(registroControllerProvider.notifier).registrar(
          nombre: _nombre.text,
          cedula: _cedula.text,
          correo: _correo.text,
          password: _password.text,
        );
    if (creada && mounted) context.go(AppRoutes.verificarCorreo);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nombre,
                enabled: !cargando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validadores.nombre,
                inputFormatters: Validadores.entradaNombre(Validadores.nombreMax),
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _cedula,
                enabled: !cargando,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: Validadores.cedula,
                inputFormatters: Validadores.entradaCedula,
                decoration: const InputDecoration(
                  labelText: 'Cédula de identidad',
                  helperText: '10 dígitos. Se valida el número, no se consulta ningún registro.',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
              const SizedBox(height: 14),
              CampoPassword(
                controller: _password,
                label: 'Contraseña',
                enabled: !cargando,
                validator: Validadores.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _password,
                builder: (_, valor, _) => RequisitosPassword(password: valor.text),
              ),
              const SizedBox(height: 14),
              CampoPassword(
                controller: _confirmacion,
                label: 'Repita la contraseña',
                enabled: !cargando,
                validator: Validadores.confirmacion(() => _password.text),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _enviar(),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                AvisoInline(texto: error),
              ],
              const SizedBox(height: 20),
              BotonDegradado(texto: 'Crear cuenta', cargando: cargando, onPressed: _enviar),
              BotonGoogle(habilitado: !cargando),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿Ya tiene una cuenta?', style: AppTextStyles.cuerpo),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
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
