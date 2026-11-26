import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/sesion_controller.dart';
import 'franja_tricolor.dart';
import 'hoja_confirmacion.dart';
import 'insignia_estado.dart';
import 'logo_kuntur.dart';
import 'navegacion_principal.dart';

/// Barra superior de las pantallas de Kuntur EC.
///
/// - En escritorio (`seccionEscritorio != null`), aloja las pestañas de navegación principal
///   como cápsulas limpias y accesibles sin necesidad de barra inferior móvil.
/// - Logo y nombre llevan al inicio correspondiente (vuelos con sesión, portada sin sesión).
/// - Menú de cuenta con ancho acotado seguro para nombres/correos largos e indicador desplegable.
class BarraKuntur extends ConsumerWidget implements PreferredSizeWidget {
  const BarraKuntur({
    super.key,
    this.conAtras = false,
    this.alTocarInicio,
    this.seccionEscritorio,
  });

  final bool conAtras;

  /// Sustituye la navegación al inicio del logo (para confirmar antes de perder datos).
  final VoidCallback? alTocarInicio;

  /// Sección activa cuando se renderiza navegación integrada en escritorio (`>= 1024 px`).
  final Seccion? seccionEscritorio;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionControllerProvider).value;
    final destinoInicio = usuario == null ? AppRoutes.inicio : AppRoutes.vuelos;
    final irInicio = alTocarInicio ?? () => context.go(destinoInicio);

    return AppBar(
      automaticallyImplyLeading: false,
      leading: conAtras
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? Navigator.of(context).maybePop() : context.go(destinoInicio),
            )
          : null,
      titleSpacing: conAtras ? 0 : null,
      title: Row(
        children: [
          Flexible(
            child: Semantics(
              button: true,
              label: 'Kuntur EC, ir al inicio',
              onTap: irInicio,
              excludeSemantics: true,
              child: Tooltip(
                message: 'Ir al inicio',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: irInicio,
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
          ),
          if (seccionEscritorio != null && usuario != null) ...[
            const SizedBox(width: 24),
            _PestanasEscritorio(actual: seccionEscritorio!, esAdmin: usuario.esAdmin),
          ],
        ],
      ),
      bottom: const PreferredSize(preferredSize: Size.fromHeight(5), child: FranjaTricolor()),
      actions: const [MenuCuenta(), SizedBox(width: 10)],
    );
  }
}

class _PestanasEscritorio extends StatelessWidget {
  const _PestanasEscritorio({required this.actual, required this.esAdmin});

  final Seccion actual;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final secciones = esAdmin
        ? const [Seccion.vuelos, Seccion.administracion]
        : const [Seccion.vuelos, Seccion.reservas];

    return Semantics(
      container: true,
      label: 'Navegación principal',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seccion in secciones)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _BotonPestanaBarra(
                seccion: seccion,
                activa: seccion == actual,
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonPestanaBarra extends StatefulWidget {
  const _BotonPestanaBarra({required this.seccion, required this.activa});

  final Seccion seccion;
  final bool activa;

  @override
  State<_BotonPestanaBarra> createState() => _BotonPestanaBarraState();
}

class _BotonPestanaBarraState extends State<_BotonPestanaBarra> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final (String etiqueta, IconData icono, String ruta) = switch (widget.seccion) {
      Seccion.vuelos => (
          'Vuelos',
          widget.activa ? Icons.flight_takeoff : Icons.flight_takeoff_outlined,
          AppRoutes.vuelos,
        ),
      Seccion.reservas => (
          'Mis reservas',
          widget.activa ? Icons.confirmation_number : Icons.confirmation_number_outlined,
          AppRoutes.reservas,
        ),
      Seccion.administracion => (
          'Administración',
          widget.activa ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
          AppRoutes.admin,
        ),
    };

    return Semantics(
      button: true,
      selected: widget.activa,
      label: etiqueta,
      onTap: () => context.go(ruta),
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1.0,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: Material(
          color: widget.activa ? AppColors.amarillo : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(ruta),
            onHighlightChanged: (v) {
              if (_presionado != v) setState(() => _presionado = v);
            },
            hoverColor: widget.activa
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icono,
                      size: 18,
                      color: widget.activa ? AppColors.azulNoche : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: widget.activa ? FontWeight.w800 : FontWeight.w600,
                        color: widget.activa ? AppColors.azulNoche : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitulo.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  usuario.correo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.nota,
                ),
                const SizedBox(height: 8),
                InsigniaEstado(
                  texto: usuario.esAdmin ? 'Administrador' : 'Cliente',
                  tipo: usuario.esAdmin ? TipoInsignia.aviso : TipoInsignia.info,
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.amarillo,
                child: Text(
                  usuario.iniciales,
                  style: const TextStyle(color: AppColors.azulNoche, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
