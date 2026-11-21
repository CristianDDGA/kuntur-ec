import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vuelos_app/services/google_proveedor.dart';

/// Doble de [ProveedorGoogle]: no abre ninguna ventana de Google. [alTocar] se entrega como `id_token`
/// cuando se toca su botón (o con [simularInicio]), igual que lo haría Google al terminar el inicio de sesión.
class ProveedorGoogleFalso implements ProveedorGoogle {
  ProveedorGoogleFalso({this.disponible = true, this.alTocar = 'id-token-de-google'});

  @override
  final bool disponible;
  final String alTocar;
  final StreamController<String> _tokens = StreamController<String>.broadcast();
  int vecesIniciado = 0;

  @override
  Stream<String> get tokens => _tokens.stream;

  @override
  Future<void> iniciar() async => vecesIniciado++;

  @override
  Widget boton() => OutlinedButton(onPressed: () => _tokens.add(alTocar), child: const Text('Continuar con Google'));

  void simularInicio(String token) => _tokens.add(token);
}
