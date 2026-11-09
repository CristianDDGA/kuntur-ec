/// Estado de disponibilidad del proveedor de servicios (API).
class EstadoServicio {
  const EstadoServicio({required this.servicio, required this.disponible, required this.hora});

  final String servicio;
  final bool disponible;
  final DateTime hora;
}
