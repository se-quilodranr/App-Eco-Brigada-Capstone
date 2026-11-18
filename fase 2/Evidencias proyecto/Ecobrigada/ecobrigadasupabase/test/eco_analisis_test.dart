import 'package:ecobrigadasupabase/core/eco_analisis.dart';
import 'package:ecobrigadasupabase/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Reporte caso({
  required String id,
  required DateTime creado,
  double lat = -36.83250,
  double lng = -73.04480,
  String tipo = 'Basura',
  String estado = 'pendiente',
  int gravedad = 3,
  int prioridad = 60,
  DateTime? cerrado,
}) => Reporte(
  id: id,
  titulo: 'Incidencia $id',
  descripcion: 'Reporte de prueba para EcoAnálisis.',
  tipo: tipo,
  direccion: 'Sector de prueba',
  comuna: 'Concepción',
  lat: lat,
  lng: lng,
  gravedad: gravedad,
  prioridad: prioridad,
  estado: estado,
  creadorUid: 'usuario-prueba',
  brigadaId: '',
  creadoEn: creado,
  actualizadoEn: cerrado ?? creado,
  cerradoEn: cerrado,
);

void main() {
  group('EcoZonas', () {
    test('agrupa tres incidencias abiertas y descarta puntos aislados', () {
      final hoy = DateTime.utc(2026, 11, 13);
      final zonas = detectarEcoZonas([
        caso(id: 'a', creado: hoy),
        caso(id: 'b', creado: hoy, lat: -36.83260),
        caso(id: 'c', creado: hoy, lat: -36.83270),
        caso(id: 'aislado', creado: hoy, lat: -36.900),
        caso(id: 'cerrado', creado: hoy,
          lat: -36.83268, estado: 'cerrado', cerrado: hoy),
      ]);
      expect(zonas, hasLength(1));
      expect(zonas.first.reportesActivos, 3);
      expect(zonas.first.reporteIds, containsAll(['a', 'b', 'c']));
      expect(zonas.first.reporteIds, isNot(contains('cerrado')));
      expect(zonas.first.radioMetros, greaterThan(0));
    });

    test('no identifica una zona cuando solo hay dos reportes', () {
      final hoy = DateTime.utc(2026, 11, 13);
      expect(detectarEcoZonas([
        caso(id: '1', creado: hoy),
        caso(id: '2', creado: hoy, lat: -36.83260),
      ]), isEmpty);
    });
  });

  group('EcoReincidencia', () {
    test('encuentra caso nuevo posterior a una limpieza cerrada', () {
      final cierre = DateTime.utc(2026, 10, 15);
      final reportes = [
        caso(id: 'anterior', creado: DateTime.utc(2026, 10, 1),
          cerrado: cierre, estado: 'cerrado'),
        caso(id: 'nuevo', creado: DateTime.utc(2026, 10, 20),
          lat: -36.83255),
      ];
      final hallados = detectarEcoReincidencia(reportes);
      expect(hallados, hasLength(1));
      expect(hallados.first.incidenciaAnterior.id, 'anterior');
      expect(hallados.first.nuevoReporte.id, 'nuevo');
      expect(hallados.first.diasDesdeCierre, 5);
    });

    test('ignora distinto tipo, lugar lejano y fechas anteriores', () {
      final cierre = DateTime.utc(2026, 10, 15);
      final reportes = [
        caso(id: 'anterior', creado: DateTime.utc(2026, 10, 1),
          cerrado: cierre, estado: 'cerrado'),
        caso(id: 'tipo', creado: DateTime.utc(2026, 10, 20),
          tipo: 'Escombros'),
        caso(id: 'lejos', creado: DateTime.utc(2026, 10, 20),
          lat: -36.900),
        caso(id: 'antes', creado: DateTime.utc(2026, 10, 10)),
      ];
      expect(detectarEcoReincidencia(reportes), isEmpty);
    });
  });

  group('EcoTendencias', () {
    test('cuenta reportes, cierres y calcula promedio móvil', () {
      // Viernes 13/11/2026: la semana actual empieza el 09/11.
      final referencia = DateTime.utc(2026, 11, 13, 12);
      final valores = calcularEcoTendencias([
        caso(id: 'semana-ant', creado: DateTime.utc(2026, 11, 3),
          estado: 'cerrado', cerrado: DateTime.utc(2026, 11, 11)),
        caso(id: 'actual-1', creado: DateTime.utc(2026, 11, 10)),
        caso(id: 'actual-2', creado: DateTime.utc(2026, 11, 12)),
      ], referencia: referencia, semanas: 3);
      expect(valores, hasLength(3));
      expect(valores[1].reportados, 1);
      expect(valores.last.reportados, 2);
      expect(valores.last.resueltos, 1);
      expect(valores.last.promedioMovil, closeTo(1, 0.001));
      expect(valores.last.cambioPorcentual, 100);
    });

    test('deja sin valor variación si el período anterior es cero', () {
      final valores = calcularEcoTendencias([
        caso(id: 'solo', creado: DateTime.utc(2026, 11, 12)),
      ], referencia: DateTime.utc(2026, 11, 13), semanas: 2);
      expect(valores.last.reportados, 1);
      expect(valores.last.cambioPorcentual, isNull);
    });
  });

  group('EcoAlerta', () {
    test('alerta vencimiento de prioridad alta y no casos cerrados', () {
      final ahora = DateTime.utc(2026, 11, 13);
      final alertas = calcularEcoAlertas([
        caso(id: 'vencido', creado: ahora.subtract(const Duration(days: 4)),
          prioridad: 90),
        caso(id: 'por-vencer',
          creado: ahora.subtract(const Duration(hours: 30)), prioridad: 90),
        caso(id: 'al-dia', creado: ahora, prioridad: 20),
        caso(id: 'cerrado', creado: ahora.subtract(const Duration(days: 12)),
          estado: 'cerrado', prioridad: 90, cerrado: ahora),
      ], referencia: ahora);
      expect(alertas, hasLength(2));
      expect(alertas.first.reporte.id, 'vencido');
      expect(alertas.first.vencida, isTrue);
      expect(alertas.last.reporte.id, 'por-vencer');
      expect(alertas.last.vencida, isFalse);
    });
  });
}
