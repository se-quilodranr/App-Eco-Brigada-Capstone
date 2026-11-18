import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Traduce un punto elegido en el mapa en comuna y sector aproximado.
/// Usa Nominatim solo al tocar un punto; nunca en bucles de marcadores.
/// Para despliegues con muchos usuarios conviene usar un backend de geocodificación.
class DireccionMapa {
  final String comuna;
  final String sector;
  const DireccionMapa({required this.comuna, required this.sector});
}

class GeocodificacionEco {
  static final Map<String, DireccionMapa> _cache = {};
  static Future<void> _cola = Future<void>.value();
  static DateTime? _ultima;

  static String _dato(Map<String, dynamic> d, List<String> campos) {
    for (final campo in campos) {
      final texto = (d[campo] ?? '').toString().trim();
      if (texto.isNotEmpty) return texto;
    }
    return '';
  }

  /// La cola espacia las solicitudes por >= 1,1 s dentro de esta sesión.
  /// El cache evita repetir coordenadas ya consultadas.
  static Future<DireccionMapa?> invertir(LatLng punto) {
    final clave = '${punto.latitude.toStringAsFixed(4)},${punto.longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(clave)) return Future.value(_cache[clave]);
    final solicitud = _cola.then((_) async {
      final ultima = _ultima;
      if (ultima != null) {
        final espera = const Duration(milliseconds: 1100) - DateTime.now().difference(ultima);
        if (espera > Duration.zero) await Future<void>.delayed(espera);
      }
      _ultima = DateTime.now();
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': punto.latitude.toString(),
        'lon': punto.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'es',
      });
      final headers = <String, String>{'Accept': 'application/json'};
      // En navegador no se permite especificar User-Agent; usa el Referer del sitio.
      if (!kIsWeb) {
        headers['User-Agent'] = 'EcoBrigadaCapstone/3.2 '
          '(https://github.com/se-quilodranr/App-Eco-Brigada-Capstone)';
      }
      final respuesta = await http.get(url, headers: headers)
        .timeout(const Duration(seconds: 10));
      if (respuesta.statusCode != 200) {
        throw StateError('La dirección automática no está disponible '
          '(HTTP ${respuesta.statusCode}).');
      }
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (json is! Map) return null;
      final datos = Map<String, dynamic>.from(json);
      final direccion = datos['address'] is Map
        ? Map<String, dynamic>.from(datos['address'] as Map)
        : <String, dynamic>{};
      final comuna = _dato(direccion, [
        'city', 'town', 'village', 'municipality', 'city_district',
      ]);
      final calle = _dato(direccion, ['road', 'pedestrian', 'residential', 'path']);
      final numero = _dato(direccion, ['house_number']);
      final sector = _dato(direccion, [
        'neighbourhood', 'suburb', 'quarter', 'hamlet', 'locality',
      ]);
      final lugar = calle.isNotEmpty ? '$calle${numero.isEmpty ? '' : ' $numero'}'
        : sector.isNotEmpty ? sector
        : _dato(datos, ['name']);
      if (comuna.isEmpty && lugar.isEmpty) return null;
      final resultado = DireccionMapa(comuna: comuna, sector: lugar);
      _cache[clave] = resultado;
      return resultado;
    });
    // La próxima solicitud continúa aun si la anterior falla.
    _cola = solicitud.then<void>((_) {}, onError: (Object _) {});
    return solicitud;
  }
}
