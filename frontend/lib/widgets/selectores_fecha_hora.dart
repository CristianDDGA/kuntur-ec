import 'package:flutter/material.dart';

import '../models/validadores_vuelo.dart';

/// Selectores de fecha y hora de la app, con los mismos textos de ayuda y
/// límites en todas las pantallas (antes se repetían tres `_elegirFecha`).
///
/// Devuelven `null` si la persona cierra el selector sin elegir.

/// Política única del dominio: desde hoy hasta el máximo de días permitido.
Future<DateTime?> elegirFechaDeVuelo(
  BuildContext context, {
  DateTime? inicial,
  String ayuda = 'Fecha del vuelo',
}) {
  final hoy = DateTime.now();
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  return elegirFechaKuntur(
    context,
    inicial: inicial ?? dia,
    primera: dia,
    ultima: dia.add(const Duration(days: ValidadoresVuelo.diasMaxAdelante)),
    ayuda: ayuda,
  );
}

/// Fecha de vigencia de una tarifa de IVA (misma ventana que un vuelo).
Future<DateTime?> elegirFechaDeTarifa(BuildContext context, {DateTime? inicial}) =>
    elegirFechaDeVuelo(context, inicial: inicial, ayuda: 'La tarifa rige desde');

/// Selector de fecha acotado entre [primera] y [ultima].
Future<DateTime?> elegirFechaKuntur(
  BuildContext context, {
  DateTime? inicial,
  required DateTime primera,
  required DateTime ultima,
  String ayuda = 'Seleccione una fecha',
}) {
  final base = inicial ?? primera;
  return showDatePicker(
    context: context,
    initialDate: base.isBefore(primera) ? primera : (base.isAfter(ultima) ? ultima : base),
    firstDate: primera,
    lastDate: ultima,
    helpText: ayuda,
    fieldLabelText: ayuda,
  );
}

/// Selector de hora con una hora inicial razonable si no hay valor.
///
/// [usar24Horas] fuerza el formato de 24 horas (los vuelos se publican así).
Future<TimeOfDay?> elegirHoraKuntur(
  BuildContext context, {
  TimeOfDay? inicial,
  String ayuda = 'Seleccione una hora',
  bool usar24Horas = false,
}) =>
    showTimePicker(
      context: context,
      initialTime: inicial ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: ayuda,
      builder: usar24Horas
          ? (ctx, hijo) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
                child: hijo!,
              )
          : null,
    );
