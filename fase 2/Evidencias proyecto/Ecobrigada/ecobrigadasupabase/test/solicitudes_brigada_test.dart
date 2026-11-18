import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/core/models.dart';

void main() {
  test('Una solicitud de ingreso conserva su identidad y estado', () {
    final ahora = DateTime.utc(2026, 11, 13);
    final solicitud = SolicitudBrigada(
      uid: 'u01', brigadaId: 'bg01', nombre: 'Ciudadano de prueba',
      estado: 'pendiente', revisadoPor: '',
      fechaSolicitud: ahora, fechaDecision: null,
    );
    final restaurada = SolicitudBrigada.fromJson(solicitud.toJson());
    expect(restaurada.uid, 'u01');
    expect(restaurada.brigadaId, 'bg01');
    expect(restaurada.estado, 'pendiente');
    expect(restaurada.fechaDecision, isNull);
  });

  test('La aprobación conserva el solicitante y registra el revisor', () {
    final solicitud = SolicitudBrigada(
      uid: 'u02', brigadaId: 'bg02', nombre: 'Vecina de prueba',
      estado: 'pendiente', revisadoPor: '',
      fechaSolicitud: DateTime.utc(2026, 11, 12), fechaDecision: null,
    );
    final aprobada = solicitud.copyWith(
      estado: 'aprobada', revisadoPor: 'lider01',
      fechaDecision: DateTime.utc(2026, 11, 13),
    );
    expect(aprobada.estado, 'aprobada');
    expect(aprobada.uid, solicitud.uid);
    expect(aprobada.revisadoPor, 'lider01');
    expect(aprobada.fechaDecision, isNotNull);
  });

  test('Un miembro aceptado se serializa sin perder su brigada', () {
    final miembro = IntegranteBrigada(
      uid: 'u03', brigadaId: 'bg01', nombre: 'Persona de prueba',
      fechaIngreso: DateTime.utc(2026, 11, 13),
    );
    final restaurado = IntegranteBrigada.fromJson(miembro.toJson());
    expect(restaurado.uid, miembro.uid);
    expect(restaurado.brigadaId, miembro.brigadaId);
    expect(restaurado.fechaIngreso, miembro.fechaIngreso);
  });
}
