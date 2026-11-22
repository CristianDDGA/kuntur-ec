import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/recuperacion_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/campo_password.dart';
import '../widgets/panel_autenticacion.dart';
import '../widgets/requisitos_password.dart';
import 'verificar_correo_page.dart' show esperaReenvioSegundos;

/// "¿Olvidó su contraseña?" (V). Dos pasos en la misma pantalla:
/// 1. la persona escribe su correo y el servidor le envía un código de 6 dígitos;
/// 2. escribe el código y la contraseña nueva. Al terminar vuelve al login para entrar con la nueva.
class RecuperarClavePage extends ConsumerStatefulWidget {
  const RecuperarClavePage({super.key});

  @override
  ConsumerState<RecuperarClavePage> createState() => _RecuperarClavePageState();
}

class _RecuperarClavePageState extends ConsumerState<RecuperarClavePage> {
  final _formularioCorreo = GlobalKey<FormState>();
  final _formularioClave = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  Timer? _reloj;
  int _espera = 0;

  /// Correo al que se pidió el código; `null` mientras se está en el primer paso.
  String? _correoEnviado;

  /// Aviso tras pedir otro código.
  String? _aviso;

  @override
  void dispose() {
    _reloj?.cancel();
    _correo.dispose();
    _codigo.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _iniciarEspera() {
    _reloj?.cancel();
    setState(() => _espera = esperaReenvioSegundos);
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _espera--);
      if (_espera <= 0) t.cancel();
    });
  }

  Future<void> _pedirCodigo({bool reenvio = false}) async {
    if (reenvio) {
      if (_espera > 0) return;
    } else if (!_formularioCorreo.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _aviso = null);
    final correo = reenvio ? _correoEnviado! : _correo.text.trim();
    final ok = await ref.read(solicitarRecuperacionControllerProvider.notifier).solicitar(correo);
    if (!mounted || !ok) return;
    setState(() {
      _correoEnviado = correo;
      if (reenvio) _aviso = 'Si el correo está registrado, le enviamos un código nuevo.';
    });
    _iniciarEspera();
  }

  Future<void> _cambiarClave() async {
    if (!_formularioClave.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(restablecerClaveControllerProvider.notifier).restablecer(
          correo: _correoEnviado!,
          codigo: _codigo.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go(AppRoutes.login);
  }

  void _otroCorreo() {
    _reloj?.cancel();
    setState(() {
      _correoEnviado = null;
      _aviso = null;
      _espera = 0;
      _codigo.clear();
      _password.clear();
      _confirmacion.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enPrimerPaso = _correoEnviado == null;
    return PanelAutenticacion(
      titulo: enPrimerPaso ? 'Recupere su contraseña' : 'Cree una contraseña nueva',
      subtitulo: enPrimerPaso
          ? 'Escriba el correo de su cuenta y le enviaremos un código de 6 dígitos.'
          : 'Si $_correoEnviado está registrado, le enviamos un código. Escríbalo aquí; vence en 10 minutos.',
      child: enPrimerPaso ? _primerPaso() : _segundoPaso(),
    );
  }

  Widget _primerPaso() {
    final estado = ref.watch(solicitarRecuperacionControllerProvider);
    final cargando = estado.isLoading;
    final error = estado.hasError && !cargando ? mensajeDeError(estado.error!) : null;
    return Form(
      key: _formularioCorreo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _correo,
            enabled: !cargando,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _pedirCodigo(),
            validator: Validadores.correo,
            inputFormatters: [LengthLimitingTextInputFormatter(Validadores.correoMax)],
            decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            AvisoInline(texto: error),
          ],
          const SizedBox(height: 20),
          BotonDegradado(texto: 'Enviar código', cargando: cargando, onPressed: _pedirCodigo),
          const SizedBox(height: 8),
          TextButton(
            onPressed: cargando ? null : () => context.go(AppRoutes.login),
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _segundoPaso() {
    final estado = ref.watch(restablecerClaveControllerProvider);
    final reenvio = ref.watch(solicitarRecuperacionControllerProvider);
    final cargando = estado.isLoading;
    final error = estado.hasError && !cargando ? mensajeDeError(estado.error!) : null;
    final errorReenvio = reenvio.hasError && !reenvio.isLoading ? mensajeDeError(reenvio.error!) : null;
    return Form(
      key: _formularioClave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _codigo,
            enabled: !cargando,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
            textInputAction: TextInputAction.next,
            validator: Validadores.codigoVerificacion,
            inputFormatters: Validadores.entradaCodigo,
            decoration: const InputDecoration(labelText: 'Código de verificación', hintText: '000000'),
          ),
          const SizedBox(height: 16),
          CampoPassword(
            controller: _password,
            label: 'Contraseña nueva',
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
            onSubmitted: (_) => _cambiarClave(),
          ),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoInline(texto: _aviso!, tipo: TipoAviso.info),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            AvisoInline(texto: error),
          ],
          if (errorReenvio != null) ...[
            const SizedBox(height: 12),
            AvisoInline(texto: errorReenvio),
          ],
          const SizedBox(height: 20),
          BotonDegradado(texto: 'Cambiar contraseña', cargando: cargando, onPressed: _cambiarClave),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: cargando || _espera > 0 || reenvio.isLoading ? null : () => _pedirCodigo(reenvio: true),
                child: Text(_espera > 0 ? 'Reenviar código en $_espera s' : 'Reenviar código'),
              ),
              TextButton(onPressed: cargando ? null : _otroCorreo, child: const Text('Usar otro correo')),
              TextButton(
                onPressed: cargando ? null : () => context.go(AppRoutes.login),
                child: const Text('Volver a iniciar sesión'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
