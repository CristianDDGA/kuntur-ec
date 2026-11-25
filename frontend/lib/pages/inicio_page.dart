import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_motion.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../controllers/vuelos_controller.dart';
import '../models/vuelo.dart';
import '../widgets/franja_tricolor.dart';
import '../widgets/logo_kuntur.dart';
import '../widgets/rejilla_adaptable.dart';

/// Ancho máximo del contenido en pantallas grandes (los fondos y el carrusel llegan al borde).
const double _anchoContenido = 1240;

/// Página de inicio pública (V de MVC):
/// delega la carga de destinos en [destinosPopularesProvider] (`controllers/vuelos_controller.dart`).
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
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
            const SizedBox(height: 48),
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
            child: LayoutBuilder(
              builder: (context, caja) {
                final estrecha = caja.maxWidth < 460;
                final marca = Semantics(
                  button: true,
                  label: 'Kuntur EC, inicio',
                  onTap: () => context.go(AppRoutes.inicio),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.inicio),
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: MarcaKuntur(tamanoLogo: estrecha ? 28 : 32, vertical: false, enOscuro: true),
                      ),
                    ),
                  ),
                );
                final iniciar = OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.symmetric(horizontal: estrecha ? 14 : 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(
                    'Iniciar sesión',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: estrecha ? 13 : 13.5),
                  ),
                );
                final crear = FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amarillo,
                    foregroundColor: AppColors.azulNoche,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.symmetric(horizontal: estrecha ? 14 : 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go(AppRoutes.registro),
                  child: Text(
                    'Crear cuenta',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: estrecha ? 13 : 13.5),
                  ),
                );
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: estrecha ? 14 : 20, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        marca,
                        Wrap(spacing: 8, runSpacing: 8, children: [iniciar, crear]),
                      ],
                    ),
                  ),
                );
              },
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
  bool _pausado = false;

  static const _regiones = [
    (
      'Sierra Andina',
      'Volcanes imponentes, ciudades coloniales y senderos ancestrales',
      'Descubre la majestuosidad de los Andes ecuatorianos con vuelos directos hacia Quito, Cuenca y Loja.',
      Icons.terrain_outlined,
      Color(0xFF1C2B40),
      Color(0xFF2A4365),
      'Vistas de cordillera',
    ),
    (
      'Costa del Pacífico',
      'Playas doradas, brisa marina y la mejor gastronomía costera',
      'Siente la calidez y dinamismo de Guayaquil, los atardeceres de Manta y la alegría de su gente.',
      Icons.waves_outlined,
      Color(0xFF1A4338),
      Color(0xFF2A6F4F),
      'Sol y playas todo el año',
    ),
    (
      'Amazonía Viva',
      'El pulmón del mundo con ríos caudalosos y biodiversidad infinita',
      'Atrévete a explorar la selva virgen y comunidades originarias volando directamente a El Coca.',
      Icons.forest_outlined,
      Color(0xFF163A29),
      Color(0xFF2B6B46),
      'Aventura en la selva',
    ),
    (
      'Islas Galápagos',
      'Un paraíso evolutivo único en el planeta',
      'Conecta con tortugas gigantes, aguas cristalinas y un ecosistema legendario protegido para la humanidad.',
      Icons.explore_outlined,
      Color(0xFF12464D),
      Color(0xFF236E76),
      'Patrimonio Natural Mundial',
    ),
  ];

  static const _fondos = [
    'assets/regiones/sierra.jpg',
    'assets/regiones/costa.jpg',
    'assets/regiones/oriente.jpg',
    'assets/regiones/galapagos.jpg',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configurarAutoAvance();
  }

  void _configurarAutoAvance() {
    _timer?.cancel();
    if (AppMotion.movimientoReducido(context)) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _pausado || !_controller.hasClients) return;
      final siguiente = (_paginaActual + 1) % _regiones.length;
      _irA(siguiente);
    });
  }

  void _irA(int indice) {
    if (!_controller.hasClients) return;
    final duracion = AppMotion.duracion(context, const Duration(milliseconds: 350));
    if (duracion == Duration.zero) {
      _controller.jumpToPage(indice);
    } else {
      _controller.animateToPage(indice, duration: duracion, curve: AppMotion.curvaSalidaFuerte);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = caja.maxWidth >= 900;
        final compacta = caja.maxWidth < 460;
        final alto = ancho ? 430.0 : (compacta ? 320.0 : 300.0);
        return Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _anchoContenido),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descubre las 4 regiones del Ecuador',
                              style: AppTextStyles.titulo.copyWith(
                                fontSize: compacta ? 22 : 28,
                                color: AppColors.azulNoche,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 580),
                              child: const Text(
                                'Vuela a través de paisajes únicos con la flota y calidez de Kuntur EC.',
                                style: AppTextStyles.cuerpo,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: IconButton.outlined(
                          tooltip: 'Región anterior',
                          icon: const Icon(Icons.chevron_left, size: 22),
                          onPressed: () => _irA((_paginaActual - 1 + _regiones.length) % _regiones.length),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: IconButton.outlined(
                          tooltip: 'Siguiente región',
                          icon: const Icon(Icons.chevron_right, size: 22),
                          onPressed: () => _irA((_paginaActual + 1) % _regiones.length),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            MouseRegion(
              onEnter: (_) => _pausado = true,
              onExit: (_) => _pausado = false,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) _pausado = true;
                  if (n is ScrollEndNotification) _pausado = false;
                  return false;
                },
                child: SizedBox(
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
                            errorBuilder: (_, _, _) => Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 80),
                                child: Icon(r.$4, size: alto * 0.65, color: Colors.white.withValues(alpha: 0.14)),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.azulNoche.withValues(alpha: 0.78),
                                  AppColors.azulNoche.withValues(alpha: 0.36),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: _anchoContenido),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: ancho ? 40 : 22),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 600),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: (caja.maxWidth - (ancho ? 80 : 44)).clamp(220.0, 600.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(r.$4, size: 15, color: AppColors.amarillo),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      r.$7,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              r.$1,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: ancho ? 44 : (compacta ? 24 : 30),
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.6,
                                                height: 1.08,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              r.$2,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: ancho ? 18 : 14.5,
                                                fontWeight: FontWeight.w700,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              r.$3,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.92),
                                                fontSize: ancho ? 15 : 13,
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 14),
                                            FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: AppColors.amarillo,
                                                foregroundColor: AppColors.azulNoche,
                                                minimumSize: const Size(44, 44),
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                              ),
                                              onPressed: () => context.go(AppRoutes.login),
                                              icon: const Icon(Icons.flight_takeoff, size: 18),
                                              label: const Text(
                                                'Explorar vuelos',
                                                style: TextStyle(fontWeight: FontWeight.w800),
                                              ),
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
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _regiones.length,
                (idx) {
                  final activa = _paginaActual == idx;
                  return Semantics(
                    button: true,
                    selected: activa,
                    label: 'Ver región ${_regiones[idx].$1}',
                    onTap: () => _irA(idx),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _irA(idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        child: AnimatedContainer(
                          duration: AppMotion.rapidaDe(context),
                          curve: AppMotion.curvaSalidaFuerte,
                          width: activa ? 26 : 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: activa ? AppColors.azul : AppColors.borde,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
            gradient: AppGradients.cielo,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.azulNoche.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, caja) {
                final apilar = caja.maxWidth < 540;
                final texto = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Puntualidad, calidez y confort en cada despegue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'En Kuntur EC cuidamos cada detalle para que tu viaje sea placentero, seguro y memorable desde que reservas hasta tu destino final.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                );
                final boton = FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amarillo,
                    foregroundColor: AppColors.azulNoche,
                    minimumSize: const Size(44, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Comenzar viaje', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                );
                if (apilar) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      texto,
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: boton),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: texto),
                    const SizedBox(width: 20),
                    boton,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. Destinos Reales desde el Controlador
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
            Text(
              'Destinos populares del Ecuador',
              style: AppTextStyles.titulo.copyWith(fontSize: 24, color: AppColors.azulNoche),
            ),
            const SizedBox(height: 6),
            const Text(
              'Rutas reales disponibles en nuestra flota con las mejores tarifas vigentes.',
              style: AppTextStyles.cuerpo,
            ),
            const SizedBox(height: 18),
            Consumer(
              builder: (context, ref, _) {
                final destinos = ref.watch(destinosPopularesProvider).value ?? destinosPopularesRespaldo;
                return RejillaAdaptable(
                  espacio: 14,
                  anchoMinimoColumna: 230,
                  hijos: [
                    for (final d in destinos)
                      _TarjetaDestino(
                        codigo: d.codigo,
                        ciudad: d.ciudad,
                        lema: d.lema,
                        precioTexto: 'Desde ${Formatos.dinero(d.precioMinimoCentavos)}',
                        onTap: () => onSeleccionarDestino(d.ciudad),
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

class _TarjetaDestino extends StatefulWidget {
  const _TarjetaDestino({
    required this.codigo,
    required this.ciudad,
    required this.lema,
    required this.precioTexto,
    required this.onTap,
  });

  final String codigo;
  final String ciudad;
  final String lema;
  final String precioTexto;
  final VoidCallback onTap;

  @override
  State<_TarjetaDestino> createState() => _TarjetaDestinoState();
}

class _TarjetaDestinoState extends State<_TarjetaDestino> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vuelos hacia ${widget.ciudad}, ${widget.precioTexto}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado ? 0.98 : 1.0,
        duration: AppMotion.presionDe(context, presionado: _presionado),
        curve: AppMotion.curvaTactil,
        child: Container(
          decoration: AppDecorations.tarjeta,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (v) {
                if (_presionado != v) setState(() => _presionado = v);
              },
              hoverColor: AppColors.infoSuave.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.infoSuave,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(widget.codigo, style: AppTextStyles.codigo.copyWith(fontSize: 11.5)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                widget.precioTexto,
                                softWrap: false,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppColors.exito,
                                  fontFeatures: AppTextStyles.tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.ciudad, style: AppTextStyles.subtitulo.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(widget.lema, style: AppTextStyles.nota),
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

// ==========================================
// 5. Beneficios para el Cliente
// ==========================================
class _SeccionBeneficiosCliente extends StatelessWidget {
  const _SeccionBeneficiosCliente();

  static const _ventajas = [
    (
      Icons.event_seat_outlined,
      'Elige tu asiento favorito',
      'Selecciona en tiempo real si prefieres ventana para admirar los volcanes o pasillo para mayor movilidad.',
    ),
    (
      Icons.shield_outlined,
      'Tu viaje protegido',
      'Seguridad total en tu reserva con confirmación inmediata y respaldo en cada vuelo de nuestra flota.',
    ),
    (
      Icons.receipt_long_outlined,
      'Comprobante al instante',
      'Descarga tu factura electrónica oficial al momento de confirmar, lista para tus declaraciones o viáticos.',
    ),
    (
      Icons.schedule_outlined,
      'Puntualidad garantizada',
      'Monitoreo continuo de despegues y aterrizajes para que llegues a tiempo a tus reuniones o vacaciones.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.superficie,
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.divisor)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoContenido),
          child: Column(
            children: [
              Text(
                '¿Por qué volar con Kuntur EC?',
                textAlign: TextAlign.center,
                style: AppTextStyles.titulo.copyWith(fontSize: 24, color: AppColors.azulNoche),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nuestra pasión es llevarte más alto con calidez y confianza.',
                textAlign: TextAlign.center,
                style: AppTextStyles.cuerpo,
              ),
              const SizedBox(height: 28),
              RejillaAdaptable(
                espacio: 24,
                anchoMinimoColumna: 240,
                hijos: [
                  for (final v in _ventajas)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.infoSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(v.$1, color: AppColors.azul, size: 22),
                        ),
                        const SizedBox(height: 12),
                        Text(v.$2, style: AppTextStyles.subtitulo.copyWith(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(v.$3, style: AppTextStyles.cuerpo.copyWith(fontSize: 13.5)),
                      ],
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
// 6. Pie de Página (Footer)
// ==========================================
class _PieDePagina extends StatelessWidget {
  const _PieDePagina();

  @override
  Widget build(BuildContext context) {
    Widget enlace(String texto, VoidCallback onTap) => TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.88),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            alignment: Alignment.centerLeft,
          ),
          onPressed: onTap,
          child: Text(texto, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        );

    return Container(
      color: AppColors.azulNoche,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoContenido),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 32,
                  runSpacing: 20,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MarcaKuntur(tamanoLogo: 28, vertical: false, enOscuro: true),
                          const SizedBox(height: 10),
                          Text(
                            'Kuntur EC · Las alas del Ecuador conectando nuestra gente y nuestras regiones con excelencia.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 6, bottom: 4),
                            child: Text(
                              'Accesos',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                          ),
                          enlace('Ingreso de clientes', () => context.go(AppRoutes.login)),
                          enlace('Registro nuevo', () => context.go(AppRoutes.registro)),
                          enlace('Estado de vuelos', () => context.push(AppRoutes.estado)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.14)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '© 2026 Kuntur EC · Aerolínea Ecuatoriana',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12.5),
                    ),
                    Text(
                      'Ecuador · Sierra · Costa · Amazonía · Galápagos',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
