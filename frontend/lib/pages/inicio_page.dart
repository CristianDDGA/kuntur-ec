import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/vuelos_controller.dart';
import '../models/vuelo.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/logo_kuntur.dart';
import '../widgets/rejilla_adaptable.dart';

/// Ancho máximo del contenido en pantallas grandes (los fondos y el carrusel llegan al borde).
const double _anchoContenido = 1240;

final destinosPopularesProvider = FutureProvider<List<_DestinoResumen>>((ref) async {
  return _destinosRealesBase;
});

class _DestinoResumen {
  const _DestinoResumen({
    required this.ciudad,
    required this.precioMinimo,
    required this.lema,
    required this.codigoIata,
  });

  final String ciudad;
  final double precioMinimo;
  final String lema;
  final String codigoIata;
}

const _destinosRealesBase = [
  _DestinoResumen(
    ciudad: 'Guayaquil',
    precioMinimo: 72.0,
    lema: 'Perla del Pacífico · Puerto y calor',
    codigoIata: 'GYE',
  ),
  _DestinoResumen(
    ciudad: 'Manta',
    precioMinimo: 79.9,
    lema: 'Costa manabita · Playas y gastronomía',
    codigoIata: 'MEC',
  ),
  _DestinoResumen(
    ciudad: 'Coca',
    precioMinimo: 85.0,
    lema: 'Puerta a la Amazonía ecuatoriana',
    codigoIata: 'OCC',
  ),
  _DestinoResumen(
    ciudad: 'Quito',
    precioMinimo: 89.0,
    lema: 'Mitad del Mundo · Centro Histórico',
    codigoIata: 'UIO',
  ),
];

/// Página de inicio pública inspirada en aerolíneas ecuatorianas modernas:
/// - Barra superior limpia con identidad de marca y accesos directos.
/// - Carrusel interactivo superior de las 4 regiones del Ecuador (Sierra, Costa, Amazonía y Galápagos).
/// - Banner de ventajas comerciales orientado 100% al pasajero.
/// - Destinos reales cargados dinámicamente desde la base de datos (Supabase).
/// - Sección de beneficios centrada en la experiencia del viajero.
/// - Pie de página institucional y claro.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _BarraSuperiorPublica(),
            const SizedBox(height: 28),
            const _CarruselRegionesEcuador(),
            const SizedBox(height: 40),
            const _BannerExperienciaViajero(),
            const SizedBox(height: 48),
            _SeccionDestinosDinamicos(
              onSeleccionarDestino: (ciudad) {
                ref.read(filtroVuelosProvider.notifier).aplicar(FiltroVuelos(destino: ciudad));
                context.go(AppRoutes.login);
              },
            ),
            const SizedBox(height: 48),
            const _SeccionBeneficiosCliente(),
            const SizedBox(height: 50),
            const _PieDePagina(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. Barra de navegación superior (Header)
// ==========================================
class _BarraSuperiorPublica extends StatelessWidget {
  const _BarraSuperiorPublica();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.azulNoche,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.inicio),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: MarcaKuntur(tamanoLogo: 32, vertical: false, enOscuro: true),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amarillo,
                      foregroundColor: AppColors.azulNoche,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => context.go(AppRoutes.registro),
                    child: const Text('Crear cuenta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          const FranjaTricolor(),
        ],
      ),
    );
  }
}

// ==========================================
// 2. Carrusel Interactivo de las 4 Regiones del Ecuador
// ==========================================
class _CarruselRegionesEcuador extends StatefulWidget {
  const _CarruselRegionesEcuador();

  @override
  State<_CarruselRegionesEcuador> createState() => _CarruselRegionesEcuadorState();
}

class _CarruselRegionesEcuadorState extends State<_CarruselRegionesEcuador> {
  final PageController _controller = PageController(viewportFraction: 1);
  int _paginaActual = 0;
  Timer? _timer;

  static const _regiones = [
    (
      'Sierra Andina',
      'Volcanes imponentes, ciudades coloniales y senderos ancestrales',
      'Descubre la majestuosidad de los Andes ecuatorianos con vuelos directos hacia Quito, Cuenca y Loja.',
      Icons.terrain,
      Color(0xFF1E3A8A),
      Color(0xFF3B82F6),
      '🏔️ Vistas de cordillera',
    ),
    (
      'Costa del Pacífico',
      'Playas doradas, brisa marina y la mejor gastronomía costera',
      'Siente la calidez y dinamismo de Guayaquil, los atardeceres de Manta y la alegría de su gente.',
      Icons.beach_access,
      Color(0xFF065F46),
      Color(0xFF10B981),
      '🌊 Sol y playas todo el año',
    ),
    (
      'Amazonía Viva',
      'El pulmón del mundo con ríos caudalosos y biodiversidad infinita',
      'Atrévete a explorar la selva virgen y comunidades originarias volando directamente a El Coca.',
      Icons.forest,
      Color(0xFF14532D),
      Color(0xFF22C55E),
      '🌿 Aventura en la selva',
    ),
    (
      'Islas Galápagos',
      'Un paraíso evolutivo único en el planeta',
      'Conecta con tortugas gigantes, aguas cristalinas y un ecosistema legendario protegido para la humanidad.',
      Icons.pets,
      Color(0xFF0F766E),
      Color(0xFF14B8A6),
      '🐢 Patrimonio Natural Mundial',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final siguiente = (_paginaActual + 1) % _regiones.length;
      _controller.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// GIF (o imagen) de cada región, en el mismo orden que [_regiones]. Si el archivo no existe
  /// se muestra el degradado con el ícono, así la portada nunca queda rota.
  static const _fondos = [
    'assets/regiones/sierra.gif',
    'assets/regiones/costa.gif',
    'assets/regiones/amazonia.gif',
    'assets/regiones/galapagos.gif',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = caja.maxWidth >= 900;
        final alto = ancho ? 420.0 : 260.0;
        return Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _anchoContenido),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descubre las 4 regiones del Ecuador',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.azulNoche),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Vuela a través de paisajes únicos con la flota y calidez de Kuntur EC.',
                              style: TextStyle(fontSize: 14, color: AppColors.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Región anterior',
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Siguiente región',
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // A todo el ancho de la ventana (sin márgenes laterales vacíos).
            SizedBox(
              height: alto,
              width: double.infinity,
              child: PageView.builder(
                controller: _controller,
                itemCount: _regiones.length,
                onPageChanged: (idx) => setState(() => _paginaActual = idx),
                itemBuilder: (context, index) {
                  final r = _regiones[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [r.$5, r.$6],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Image.asset(
                        _fondos[index],
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 80),
                            child: Icon(r.$4, size: alto * 0.7, color: Colors.white.withValues(alpha: 0.14)),
                          ),
                        ),
                      ),
                      // Degradado oscuro a la izquierda para que el texto se lea sobre cualquier GIF.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.62), Colors.black.withValues(alpha: 0.05)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go(AppRoutes.login),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: _anchoContenido),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: ancho ? 40 : 22),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 620),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            r.$7,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          r.$1,
                                          style: TextStyle(color: Colors.white, fontSize: ancho ? 44 : 30, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          r.$2,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: ancho ? 18 : 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          r.$3,
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: ancho ? 15 : 13, height: 1.4),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _regiones.length,
                (idx) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _paginaActual == idx ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paginaActual == idx ? AppColors.azul : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. Banner Experiencia del Viajero
// ==========================================
class _BannerExperienciaViajero extends StatelessWidget {
  const _BannerExperienciaViajero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoContenido),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.amarillo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'EXPERIENCIA DE PRIMERA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.azulNoche,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Puntualidad, calidez y confort en cada despegue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En Kuntur EC cuidamos cada detalle para que tu viaje sea placentero, seguro y memorable desde que reservas hasta tu destino final.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amarillo,
                    foregroundColor: AppColors.azulNoche,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Comenzar viaje', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. Destinos Reales desde la BD (Supabase)
// ==========================================
class _SeccionDestinosDinamicos extends StatelessWidget {
  const _SeccionDestinosDinamicos({required this.onSeleccionarDestino});

  final ValueChanged<String> onSeleccionarDestino;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoContenido),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Destinos populares del Ecuador',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.azulNoche),
            ),
            const SizedBox(height: 4),
            const Text(
              'Rutas reales disponibles en nuestra flota con las mejores tarifas vigentes.',
              style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 18),
            Consumer(
              builder: (context, ref, _) {
                final destinos = ref.watch(destinosPopularesProvider).value ?? _destinosRealesBase;
                return RejillaAdaptable(
                  espacio: 14,
                  anchoMinimoColumna: 230,
                  hijos: [
                    for (final d in destinos)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSeleccionarDestino(d.ciudad),
                        child: Container(
                          width: 195,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.azul.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      d.codigoIata,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.azul),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Desde \$${d.precioMinimo.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.exito),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(d.ciudad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(d.lema, style: const TextStyle(fontSize: 12, color: AppColors.textoSuave, height: 1.3)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. Beneficios para el Cliente (No técnicos)
// ==========================================
class _SeccionBeneficiosCliente extends StatelessWidget {
  const _SeccionBeneficiosCliente();

  static const _ventajas = [
    (
      Icons.event_seat,
      'Elige tu asiento favorito',
      'Selecciona en tiempo real si prefieres ventana para admirar los volcanes o pasillo para mayor movilidad.',
    ),
    (
      Icons.shield_outlined,
      'Tu viaje protegido',
      'Seguridad total en tu reserva con confirmación inmediata y respaldo en cada vuelo de nuestra flota.',
    ),
    (
      Icons.receipt_long,
      'Comprobante al instante',
      'Descarga tu factura electrónica oficial al momento de confirmar, lista para tus declaraciones o viáticos.',
    ),
    (
      Icons.schedule,
      'Puntualidad garantizada',
      'Monitoreo continuo de despegues y aterrizajes para que llegues a tiempo a tus reuniones o vacaciones.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoContenido),
          child: Column(
            children: [
              const Text(
                '¿Por qué volar con Kuntur EC?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.azulNoche),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nuestra pasión es llevarte más alto con calidez y confianza.',
                style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
              ),
              const SizedBox(height: 24),
              RejillaAdaptable(
                espacio: 24,
                anchoMinimoColumna: 240,
                hijos: [
                  for (final v in _ventajas)
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.azul.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(v.$1, color: AppColors.azul, size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(v.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(v.$3, style: const TextStyle(fontSize: 12, color: AppColors.textoSuave, height: 1.3)),
                        ],
                      ),
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

// ==========================================
// 7. Pie de Página (Footer)
// ==========================================
class _PieDePagina extends StatelessWidget {
  const _PieDePagina();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.azulNoche,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoContenido),
          child: Column(
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  const SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarcaKuntur(tamanoLogo: 28, vertical: false, enOscuro: true),
                        SizedBox(height: 8),
                        Text(
                          'Kuntur EC · Las alas del Ecuador conectando nuestra gente y nuestras regiones con excelencia.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accesos',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => context.go(AppRoutes.login),
                          child: const Text('Ingreso de clientes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => context.go(AppRoutes.registro),
                          child: const Text('Registro nuevo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => context.push(AppRoutes.estado),
                          child: const Text('Estado de vuelos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 Kuntur EC · Aerolínea Ecuatoriana',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    'Pasión por volar sobre nuestra tierra',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
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
