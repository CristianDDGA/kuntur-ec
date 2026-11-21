import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../controllers/sesion_controller.dart';
import '../controllers/verificacion_controller.dart';
import '../models/validadores.dart';
import '../services/api_exception.dart';
import '../widgets/aviso.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/panel_autenticacion.dart';

/// Segundos que hay que esperar entre un código y el siguiente (el servidor aplica la misma regla).
const int esperaReenvioSegundos = 60;

/// "Confirme su correo" (V): la persona escribe el código de 6 dígitos que llegó a su correo.
/// Después de confirmarlo inicia sesión sola.
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

  /// Aviso tras pedir otro código ("Le enviamos un código nuevo.").
  String? _aviso;

  @override
  void initState() {
    super.initState();
    final pendiente = ref.read(verificacionPendienteProvider);
    if (pendiente == null) return;
    if (pendiente.enviarAlEntrar) {
      // El correo del registro no salió, o llegó desde el login: se pide un código al abrir la pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reenviar());
    } else {
      _iniciarEspera(); // el código acaba de enviarse: se puede pedir otro en un minuto
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

    // Correo verificado pero el inicio de sesión automático falló: se lleva al login con el motivo.
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
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
                  child: Text(_espera > 0 ? 'Reenviar código en $_espera s' : 'Reenviar código'),
                ),
                TextButton(onPressed: verificando ? null : _volver, child: const Text('Volver a iniciar sesión')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
