import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'models.dart';

const estadosPermitidos = <String, List<String>>{
  'pendiente': ['validado', 'descartado'],
  'validado': ['asignado', 'descartado'],
  'asignado': ['en_proceso'],
  'en_proceso': ['en_revision'],
  'en_revision': ['cerrado', 'en_proceso'],
  'cerrado': [],
  'descartado': [],
};

bool transicionValida(String actual, String nuevo) =>
    estadosPermitidos[actual]?.contains(nuevo) ?? false;

int calcularPrioridad({required int gravedad, required int diasAbierto,
  required int reportesCercanos}) =>
    (gravedad.clamp(1, 5) * 13 + min(20, max(0, diasAbierto)) +
     min(15, max(0, reportesCercanos) * 5)).clamp(0, 100).toInt();

String prioridadEtiqueta(int valor) => valor >= 75
    ? 'Alta' : valor >= 45 ? 'Media' : 'Baja';

/// EcoRadar: comparación espacial + mismo tipo; no usa datos entrenados.
List<Reporte> buscarDuplicados({required LatLng posicion,
  required String tipo, required Iterable<Reporte> reportes, double metros = 150}) {
  const d = Distance();
  return reportes.where((r) => r.abierto && r.tipo == tipo &&
      d.as(LengthUnit.Meter, posicion, r.punto) <= metros).toList();
}

class Recomendacion {
  final Brigada brigada;
  final int puntuacion;
  final double kilometros;
  const Recomendacion(this.brigada, this.puntuacion, this.kilometros);
}

/// EcoMatch: puntuación determinística auditable; no es Machine Learning.
List<Recomendacion> recomendarBrigadas(Reporte reporte,
    Iterable<Brigada> brigadas, Iterable<Reporte> reportes) {
  const d = Distance();
  final resultado = <Recomendacion>[];
  for (final b in brigadas) {
    if (!b.disponible) continue;
    final km = d.as(LengthUnit.Kilometer, reporte.punto, b.punto);
    final activos = reportes.where((r) => r.brigadaId == b.id && r.abierto).length;
    final cercania = (50 - km * 6).clamp(0, 50);
    final capacidad = (b.miembros * 3).clamp(0, 24);
    final carga = (26 - activos * 8).clamp(0, 26);
    resultado.add(Recomendacion(b, (cercania + capacidad + carga).round(), km));
  }
  resultado.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));
  return resultado;
}

String campoCsv(String valor) => '"${valor.replaceAll('"', '""')}"';

String generarCsv(Iterable<Reporte> reportes) {
  final rows = <String>[
    'ID,Titulo,Tipo,Comuna,Estado,Gravedad,Prioridad,Brigada,Creado,Cerrado',
  ];
  for (final r in reportes) {
    rows.add([
      r.id, r.titulo, r.tipo, r.comuna, estadoNombre(r.estado),
      '${r.gravedad}', '${r.prioridad}', r.brigadaId,
      r.creadoEn.toIso8601String(), r.cerradoEn?.toIso8601String() ?? '',
    ].map(campoCsv).join(','));
  }
  return '\uFEFF${rows.join('\r\n')}\r\n';
}
