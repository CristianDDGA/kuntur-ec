import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import 'franja_tricolor.dart';
import 'hoja_confirmacion.dart';
import 'insignia_estado.dart';
import 'logo_kuntur.dart';

/// Barra superior de las pantallas con sesión.
///
/// - Logo y nombre: tocarlos lleva siempre al inicio (así nadie se pierde).
/// - Flecha "Volver" (si [conAtras]).
/// - Menú de cuenta: quién está conectado, estado del servicio y cerrar sesión (con confirmación).
class BarraKuntur extends ConsumerWidget implements PreferredSizeWidget {
  const BarraKuntur({super.key, this.conAtras = false, this.alTocarInicio});

  final bool conAtras;

  /// Sustituye la navegación al inicio del logo (las pantallas con datos sin
  /// guardar lo usan para pedir confirmación antes de salir).
  final VoidCallback? alTocarInicio;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: conAtras
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              // maybePop (y no pop) respeta los avisos de "¿Salir sin guardar?" de las pantallas que los tengan.
              onPressed: () => context.canPop() ? Navigator.of(context).maybePop() : context.go(AppRoutes.vuelos),
            )
          : null,
      titleSpacing: conAtras ? 0 : null,
      title: Semantics(
        button: true,
        label: 'Kuntur EC, ir al inicio',
        onTap: alTocarInicio ?? () => context.go(AppRoutes.vuelos),
        excludeSemantics: true,
        child: Tooltip(
          message: 'Ir al inicio',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: alTocarInicio ?? () => context.go(AppRoutes.vuelos),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MarcaKuntur(tamanoLogo: 34, vertical: false, enOscuro: true),
                ),
              ),
            ),
          ),
        ),
      ),
      bottom: const PreferredSize(preferredSize: Size.fromHeight(5), child: FranjaTricolor()),
      actions: const [MenuCuenta(), SizedBox(width: 8)],
    );
  }
}

/// Avatar con las iniciales del usuario; al tocarlo muestra sus datos y las opciones de la cuenta.
class MenuCuenta extends ConsumerWidget {
  const MenuCuenta({super.key});

  static const _estado = 'estado';
  static const _salir = 'salir';

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmado = await mostrarConfirmacionKuntur(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: 'Tendrá que volver a ingresar su correo y contraseña para entrar.',
      textoConfirmar: 'Sí, cerrar sesión',
      textoCancelar: 'Seguir conectado',
      estilo: EstiloConfirmacion.destructiva,
      icono: Icons.logout,
    );
    if (confirmado) await ref.read(sesionControllerProvider.notifier).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Cuenta de ${usuario.nombre}',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (valor) {
        if (valor == _estado) context.push(AppRoutes.estado);
        if (valor == _salir) _cerrarSesion(context, ref);
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usuario.nombre, style: AppTextStyles.subtitulo.copyWith(fontSize: 15)),
              Text(usuario.correo, style: AppTextStyles.nota),
              const SizedBox(height: 6),
              InsigniaEstado(
                texto: usuario.esAdmin ? 'Administrador' : 'Cliente',
                tipo: usuario.esAdmin ? TipoInsignia.aviso : TipoInsignia.info,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: _estado,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_done_outlined),
            title: Text('Estado del servicio'),
          ),
        ),
        const PopupMenuItem<String>(
          value: _salir,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text('Cerrar sesión', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.amarillo,
          child: Text(
            usuario.iniciales,
            style: const TextStyle(color: AppColors.azulNoche, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
