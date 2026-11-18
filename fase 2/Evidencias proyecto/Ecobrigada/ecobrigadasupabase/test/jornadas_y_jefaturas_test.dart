import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/core/models.dart';

void main() {
  group('Jornadas', () {
    test('conserva el estado de una jornada finalizada en la base de datos', () {
      final jornada = Jornada.fromJson({
        'id': 'jornada-1',
        'titulo': 'Retiro de residuos',
        'brigadaId': 'brigada-1',
        'lugar': 'Sector de prueba',
        'fecha': '2026-11-12T12:00:00Z',
        'estado': 'finalizada',
      });
      expect(jornada.estado, 'finalizada');
      expect(jornada.toJson()['estado'], 'finalizada');
    });
    test('asigna programada cuando un registro antiguo no tiene estado', () {
      final jornada = Jornada.fromJson({
        'id': 'jornada-2',
        'titulo': 'Revisión',
        'brigadaId': 'brigada-1',
        'lugar': 'Concepción',
        'fecha': '2026-11-25T12:00:00Z',
      });
      expect(jornada.estado, 'programada');
    });
  });
  test('cada brigada tiene un UUID de jefe que puede distinguirse de otros', () {
    final b1 = Brigada.fromJson({
      'id': 'b1', 'nombre': 'Brigada A', 'descripcion': 'Prueba',
      'comuna': 'Concepción', 'liderUid': 'jefe-a',
      'lat': -36.8, 'lng': -73.0, 'miembros': 1, 'disponible': true,
    });
    final b2 = Brigada.fromJson({
      'id': 'b2', 'nombre': 'Brigada B', 'descripcion': 'Prueba',
      'comuna': 'Talcahuano', 'liderUid': 'jefe-b',
      'lat': -36.7, 'lng': -73.1, 'miembros': 1, 'disponible': true,
    });
    expect(b1.liderUid, isNot(b2.liderUid));
  });
}
