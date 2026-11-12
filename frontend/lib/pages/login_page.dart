import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/login_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_password.dart';
import '../widgets/panel_autenticacion.dart';

/// Vista (V de MVC) del inicio de sesión. No llama a la API: delega en [LoginController].
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(loginControllerProvider.notifier).ingresar(
          correo: _correo.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(loginControllerProvider);
    final cargando = estado.isLoading;
    final error = estado.hasError && !cargando ? mensajeDeError(estado.error!) : null;
    final aviso = ref.watch(avisoLoginProvider); // p. ej. "Su sesión venció por seguridad…"

    return PanelAutenticacion(
      titulo: 'Bienvenido de vuelta',
      subtitulo: 'Inicie sesión para consultar y reservar sus vuelos.',
      child: AutofillGroup(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (aviso != null) ...[
                AvisoInline(texto: aviso, tipo: TipoAviso.info),
                const SizedBox(height: 16),
              ],
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
              const SizedBox(height: 16),
              CampoPassword(
                controller: _password,
                label: 'Contraseña',
                enabled: !cargando,
                validator: Validadores.passwordIngreso,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _enviar(),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                AvisoInline(texto: error),
              ],
              const SizedBox(height: 24),
              BotonDegradado(texto: 'Iniciar sesión', cargando: cargando, onPressed: _enviar),
              const SizedBox(height: 12),
              // Wrap: si no cabe en una línea (pantallas angostas) el enlace baja a la siguiente.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿Aún no tiene cuenta?'),
                  TextButton(
                    onPressed: cargando ? null : () => context.go(AppRoutes.registro),
                    child: const Text('Cree una'),
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
