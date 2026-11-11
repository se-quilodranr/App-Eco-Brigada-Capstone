import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Resultado agregado por DBSCAN desde un proceso administrador.
/// Una zona critica NO predice contaminacion futura.
class ZonaCritica {
  final String id;
  final LatLng centro;
  final double radioMetros;
  final int cantidadReportes;
  final String prioridad;

  const ZonaCritica({
    required this.id,
    required this.centro,
    required this.radioMetros,
    required this.cantidadReportes,
    required this.prioridad,
  });

  factory ZonaCritica.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final gps = data['centro'] as GeoPoint;
    return ZonaCritica(
      id: doc.id,
      centro: LatLng(gps.latitude, gps.longitude),
      radioMetros: (data['radioMetros'] as num).toDouble(),
      cantidadReportes: (data['cantidadReportes'] as num).toInt(),
      prioridad: (data['prioridad'] ?? 'inicial').toString(),
    );
  }
}
