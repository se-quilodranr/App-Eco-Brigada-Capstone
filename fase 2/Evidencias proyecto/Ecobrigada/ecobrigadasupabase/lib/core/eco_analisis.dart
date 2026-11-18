import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Algoritmos determinísticos de análisis sobre las incidencias disponibles.
/// No son predicciones ni mediciones físicas de contaminación.
/// El store carga hasta 1500 incidencias desde Supabase; los
/// resultados representan únicamente esa muestra cargada.

class ZonaEco {
  final LatLng centro;
  final double radioMetros;
  final int reportesActivos;
  final int gravedadMaxima;
  final int indice;
  final String comuna;
  final List<String> reporteIds;

  const ZonaEco({
    required this.centro,
    required this.radioMetros,
    required this.reportesActivos,
    required this.gravedadMaxima,
    required this.indice,
    required this.comuna,
    required this.reporteIds,
  });

  String get nivel => indice >= 75 ? 'Alta' : indice >= 45 ? 'Media' : 'Baja';
}

/// EcoZonas: componentes conexas de un grafo espacial; dos incidencias
/// quedan conectadas si están a [distanciaMetros] o menos. No es DBSCAN.
/// Es O(n²), adecuado para la muestra limitada de este MVP.
List<ZonaEco> detectarEcoZonas(
  Iterable<Reporte> reportes, {
  double distanciaMetros = 250,
  int minReportes = 3,
}) {
  if (distanciaMetros <= 0 || minReportes < 2) {
    throw ArgumentError('Radio y mínimo de reportes no válidos.');
  }
  final datos = reportes.where((r) => r.abierto &&
      r.lat >= -90 && r.lat <= 90 && r.lng >= -180 && r.lng <= 180).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final visitados = <int>{};
  final zonas = <ZonaEco>[];
  const distance = Distance();

  for (var i = 0; i < datos.length; i++) {
    if (visitados.contains(i)) continue;
    final cola = <int>[i];
    final grupo = <Reporte>[];
    visitados.add(i);
    var cursor = 0;
    while (cursor < cola.length) {
      final actual = datos[cola[cursor++]];
      grupo.add(actual);
      for (var j = 0; j < datos.length; j++) {
        if (visitados.contains(j)) continue;
        if (distance.as(LengthUnit.Meter, actual.punto, datos[j].punto) <=
            distanciaMetros) {
          visitados.add(j);
          cola.add(j);
        }
      }
    }
    if (grupo.length < minReportes) continue;

    final centro = LatLng(
      grupo.map((r) => r.lat).reduce((a, b) => a + b) / grupo.length,
      grupo.map((r) => r.lng).reduce((a, b) => a + b) / grupo.length,
    );
    final dispersion = grupo.map((r) =>
        distance.as(LengthUnit.Meter, centro, r.punto)).reduce(max);
    final gravedad = grupo.map((r) => r.gravedad).reduce(max);
    final comunas = grupo.map((r) => r.comuna.trim()).toSet();
    zonas.add(ZonaEco(
      centro: centro,
      radioMetros: max(120.0, dispersion + 50),
      reportesActivos: grupo.length,
      gravedadMaxima: gravedad,
      indice: min(100, grupo.length * 12 + gravedad * 10),
      comuna: comunas.length == 1 ? comunas.first : 'Varias comunas',
      reporteIds: List.unmodifiable(grupo.map((r) => r.id)),
    ));
  }
  zonas.sort((a, b) {
    final diferencia = b.indice.compareTo(a.indice);
    return diferencia != 0 ? diferencia :
        b.reportesActivos.compareTo(a.reportesActivos);
  });
  return zonas;
}

class ReincidenciaEco {
  final Reporte incidenciaAnterior;
  final Reporte nuevoReporte;
  final double distanciaMetros;
  final int diasDesdeCierre;

  const ReincidenciaEco({
    required this.incidenciaAnterior,
    required this.nuevoReporte,
    required this.distanciaMetros,
    required this.diasDesdeCierre,
  });
}

/// EcoReincidencia: un nuevo reporte abierto, del mismo tipo, aparece DESPUÉS
/// del cierre de otro reporte próximo. Indica posible recurrencia, no certeza.
/// Devuelve una coincidencia (la más reciente) por cada nuevo reporte.
List<ReincidenciaEco> detectarEcoReincidencia(
  Iterable<Reporte> reportes, {
  double distanciaMetros = 150,
  int maxDiasDesdeCierre = 180,
}) {
  if (distanciaMetros <= 0 || maxDiasDesdeCierre < 1) {
    throw ArgumentError('Parámetros de reincidencia no válidos.');
  }
  final datos = reportes.toList();
  final cerrados = datos.where((r) =>
      r.estado == 'cerrado' && r.cerradoEn != null).toList();
  final abiertos = datos.where((r) => r.abierto).toList();
  const distance = Distance();
  final resultado = <ReincidenciaEco>[];

  for (final actual in abiertos) {
    ReincidenciaEco? mejor;
    for (final previo in cerrados) {
      if (actual.id == previo.id || actual.tipo != previo.tipo) continue;
      final transcurridos = actual.creadoEn.difference(previo.cerradoEn!).inDays;
      if (actual.creadoEn.isBefore(previo.cerradoEn!) ||
          transcurridos > maxDiasDesdeCierre) {
        continue;
      }
      final metros = distance.as(
        LengthUnit.Meter, actual.punto, previo.punto,
      );
      if (metros > distanciaMetros) continue;
      final candidata = ReincidenciaEco(
        incidenciaAnterior: previo,
        nuevoReporte: actual,
        distanciaMetros: metros,
        diasDesdeCierre: transcurridos,
      );
      if (mejor == null ||
          previo.cerradoEn!.isAfter(mejor.incidenciaAnterior.cerradoEn!) ||
          (previo.cerradoEn == mejor.incidenciaAnterior.cerradoEn &&
              metros < mejor.distanciaMetros)) {
        mejor = candidata;
      }
    }
    if (mejor != null) resultado.add(mejor);
  }
  resultado.sort((a, b) =>
      b.nuevoReporte.creadoEn.compareTo(a.nuevoReporte.creadoEn));
  return resultado;
}

class SemanaEco {
  final DateTime inicio;
  final int reportados;
  final int resueltos;
  final double promedioMovil;
  final double? cambioPorcentual;

  const SemanaEco({
    required this.inicio,
    required this.reportados,
    required this.resueltos,
    required this.promedioMovil,
    required this.cambioPorcentual,
  });
}

DateTime _inicioSemana(DateTime fecha) {
  final dia = fecha.isUtc
      ? DateTime.utc(fecha.year, fecha.month, fecha.day)
      : DateTime(fecha.year, fecha.month, fecha.day);
  return dia.subtract(Duration(days: dia.weekday - DateTime.monday));
}

/// EcoTendencias: conteos semanales y media móvil de tres semanas.
/// Las semanas vacías se conservan; la variación queda nula cuando el
/// período anterior tiene cero reportes (no se divide entre cero).
List<SemanaEco> calcularEcoTendencias(
  Iterable<Reporte> reportes, {
  required DateTime referencia,
  int semanas = 8,
}) {
  if (semanas < 2 || semanas > 52) {
    throw ArgumentError('Usa entre 2 y 52 semanas.');
  }
  final datos = reportes.toList();
  final semanaActual = _inicioSemana(referencia);
  final nuevos = <int>[];
  final cerrados = <int>[];

  for (var i = 0; i < semanas; i++) {
    final desde = semanaActual.subtract(Duration(days: (semanas - 1 - i) * 7));
    final hasta = desde.add(const Duration(days: 7));
    nuevos.add(datos.where((r) =>
        !r.creadoEn.isBefore(desde) && r.creadoEn.isBefore(hasta) &&
        !r.creadoEn.isAfter(referencia)).length);
    cerrados.add(datos.where((r) =>
        r.cerradoEn != null && !r.cerradoEn!.isBefore(desde) &&
        r.cerradoEn!.isBefore(hasta) &&
        !r.cerradoEn!.isAfter(referencia)).length);
  }
  return [
    for (var i = 0; i < semanas; i++)
      SemanaEco(
        inicio: semanaActual.subtract(Duration(days: (semanas - 1 - i) * 7)),
        reportados: nuevos[i],
        resueltos: cerrados[i],
        promedioMovil: nuevos.sublist(max(0, i - 2), i + 1)
            .reduce((a, b) => a + b) / min(i + 1, 3),
        cambioPorcentual: i == 0 || nuevos[i - 1] == 0
            ? null
            : (nuevos[i] - nuevos[i - 1]) * 100 / nuevos[i - 1],
      ),
  ];
}

class AlertaEco {
  final Reporte reporte;
  final int plazoDias;
  final int diasTranscurridos;
  final int horasRestantes;

  const AlertaEco({
    required this.reporte,
    required this.plazoDias,
    required this.diasTranscurridos,
    required this.horasRestantes,
  });

  bool get vencida => horasRestantes <= 0;
  String get etiqueta => vencida ? 'Vencida' : 'Por vencer';
}

/// EcoAlerta: plazo orientativo según prioridad (alta: 2 días,
/// media: 5 días, baja: 10 días). Alerta cuando quedan <= 24 horas.
/// No envía notificaciones ni constituye un SLA acordado con una institución.
List<AlertaEco> calcularEcoAlertas(
  Iterable<Reporte> reportes, {
  required DateTime referencia,
}) {
  final resultado = <AlertaEco>[];
  for (final r in reportes) {
    if (!r.abierto) continue;
    final plazo = r.prioridad >= 75 ? 2 : r.prioridad >= 45 ? 5 : 10;
    final antiguedad = referencia.difference(r.creadoEn).inHours;
    if (antiguedad < 0) continue;
    final restante = plazo * 24 - antiguedad;
    if (restante > 24) continue;
    resultado.add(AlertaEco(
      reporte: r,
      plazoDias: plazo,
      diasTranscurridos: referencia.difference(r.creadoEn).inDays,
      horasRestantes: restante,
    ));
  }
  resultado.sort((a, b) => a.horasRestantes.compareTo(b.horasRestantes));
  return resultado;
}
