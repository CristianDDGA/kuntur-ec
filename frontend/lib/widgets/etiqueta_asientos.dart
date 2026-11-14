import 'package:flutter/material.dart';

import '../models/vuelo.dart';
import 'insignia_estado.dart';

/// Disponibilidad del vuelo: "Agotado", "Quedan 3" o "42 asientos".
///
/// Es una [InsigniaEstado] más: una sola forma de pintar píldoras en toda la app.
class EtiquetaAsientos extends StatelessWidget {
  const EtiquetaAsientos({super.key, required this.vuelo});

  final Vuelo vuelo;

  @override
  Widget build(BuildContext context) {
    final (texto, tipo) = vuelo.agotado
        ? ('Agotado', TipoInsignia.error)
        : vuelo.pocosAsientos
            ? ('Quedan ${vuelo.asientosDisponibles}', TipoInsignia.aviso)
            : ('${vuelo.asientosDisponibles} asientos', TipoInsignia.exito);
    return InsigniaEstado(texto: texto, tipo: tipo);
  }
}
