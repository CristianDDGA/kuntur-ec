import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../widgets/boton_degradado.dart';
import '../widgets/isometric_kuntur.dart';
import '../widgets/kinetic_type.dart';
import '../widgets/logo_kuntur.dart';

/// Página de inicio pública: presenta Kuntur EC y lleva a iniciar sesión o crear una cuenta.
/// Quien ya tiene sesión nunca la ve: el router lo manda directo a la lista de vuelos.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  static const _ventajas = [
    (Icons.search, 'Encuentre su vuelo', 'Busque por origen, destino y fecha, y compare precios con el IVA incluido.'),
    (Icons.event_seat_outlined, 'Elija su asiento', 'Vea el mapa de la cabina y reserve exactamente los lugares que quiere.'),
    (Icons.receipt_long_outlined, 'Comprobante al instante', 'Descargue la factura de su reserva en XML cuando la necesite.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.fondo),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MarcaKuntur(vertical: false)),
                    const SizedBox(height: 24),
                    const HeroIsometricoAndes(alto: 190),
                    const SizedBox(height: 24),
                    const TituloCinetico('Vuele por los cielos del Ecuador', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text(
                      'Reserve vuelos nacionales de forma simple y segura, con el precio final claro desde el primer momento.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cuerpo,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 200,
                          child: BotonDegradado(texto: 'Iniciar sesión', onPressed: () => context.go(AppRoutes.login)),
                        ),
                        SizedBox(
                          width: 200,
                          child: BotonDegradado(
                            texto: 'Crear cuenta',
                            variante: VarianteBoton.secundario,
                            onPressed: () => context.go(AppRoutes.registro),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [for (final v in _ventajas) _TarjetaVentaja(icono: v.$1, titulo: v.$2, texto: v.$3)],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.estado),
                        child: const Text('Estado del servicio'),
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

class _TarjetaVentaja extends StatelessWidget {
  const _TarjetaVentaja({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        width: 232,
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.tarjeta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppColors.azul, size: 28),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(texto, style: AppTextStyles.nota),
          ],
        ),
      );
}
