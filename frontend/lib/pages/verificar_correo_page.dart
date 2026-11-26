import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/verificacion_controller.dart';
import '../models/fallo.dart';
import '../models/validadores.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/panel_autenticacion.dart';

/// Segundos que hay que esperar entre un código y el siguiente (el servidor aplica la misma regla).
const int esperaReenvioSegundos = 60;

/// "Confirme su correo" (V): código OTP de 6 dígitos con autofill y contador tabular.
class VerificarCorreoPage extends ConsumerStatefulWidget {
  const VerificarCorreoPage({super.key});

  @override
  ConsumerState<VerificarCorreoPage> createState() => _VerificarCorreoPageState();
}

class _VerificarCorreoPageState extends ConsumerState<VerificarCorreoPage> {
  final _formulario = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  Timer? _reloj;
  int _espera = 0;

  String? _aviso;

  @override
  void initState() {
    super.initState();
    final pendiente = ref.read(verificacionPendienteProvider);
    if (pendiente == null) return;
    if (pendiente.enviarAlEntrar) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reenviar());
    } else {
      _iniciarEspera();
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
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

  Future<void> _reenviar() async {
    if (_espera > 0) return;
    setState(() => _aviso = null);
    final ok = await ref.read(reenviarCodigoControllerProvider.notifier).reenviar();
    if (!mounted) return;
    if (ok) setState(() => _aviso = 'Si el correo está registrado, le enviamos un código nuevo.');
    _iniciarEspera();
  }

  Future<void> _verificar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(verificarCorreoControllerProvider.notifier).verificar(_codigo.text.trim());
  }

  void _volver() {
    ref.read(verificacionPendienteProvider.notifier).limpiar();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = ref.watch(verificacionPendienteProvider);
    final estado = ref.watch(verificarCorreoControllerProvider);
    final reenvio = ref.watch(reenviarCodigoControllerProvider);
    final verificando = estado.isLoading;

    ref.listen(verificarCorreoControllerProvider, (_, siguiente) {
      final error = siguiente.error;
      if (error is ServerFailure && error.codigo == codigoVerificadoSinSesion) {
        ref.read(avisoLoginProvider.notifier).mostrar(error.mensaje);
        context.go(AppRoutes.login);
      }
    });

    final error = estado.hasError && !verificando ? mensajeDeError(estado.error!) : null;
    final errorReenvio = reenvio.hasError && !reenvio.isLoading ? mensajeDeError(reenvio.error!) : null;

    return PanelAutenticacion(
      titulo: 'Confirme su correo',
      subtitulo: pendiente == null
          ? 'Inicie sesión para continuar.'
          : 'Enviamos un código de 6 dígitos a ${pendiente.correo}. Escríbalo aquí; vence en 10 minutos.',
      child: AutofillGroup(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _codigo,
                enabled: !verificando,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTextStyles.tabular,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _verificar(),
                validator: Validadores.codigoVerificacion,
                inputFormatters: Validadores.entradaCodigo,
                decoration: const InputDecoration(labelText: 'Código de verificación', hintText: '000000'),
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
              BotonDegradado(texto: 'Verificar', cargando: verificando, onPressed: _verificar),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: verificando || _espera > 0 || reenvio.isLoading ? null : _reenviar,
                    child: Text(
                      _espera > 0 ? 'Reenviar código en $_espera s' : 'Reenviar código',
                      style: const TextStyle(fontFeatures: AppTextStyles.tabular),
                    ),
                  ),
                  TextButton(onPressed: verificando ? null : _volver, child: const Text('Volver a iniciar sesión')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
