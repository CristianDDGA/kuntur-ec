import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Descarga real de un archivo de texto desde el navegador (sin depender de paquetes extra).
bool descargarTexto(String nombre, String contenido, {String tipo = 'application/xml'}) {
  final doc = globalContext['document'] as JSObject;
  final enlace = doc.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  enlace['href'] = 'data:$tipo;charset=utf-8,${Uri.encodeComponent(contenido)}'.toJS;
  enlace['download'] = nombre.toJS;
  final cuerpo = doc['body'] as JSObject;
  cuerpo.callMethod<JSAny?>('appendChild'.toJS, enlace);
  enlace.callMethod<JSAny?>('click'.toJS);
  cuerpo.callMethod<JSAny?>('removeChild'.toJS, enlace);
  return true;
}
