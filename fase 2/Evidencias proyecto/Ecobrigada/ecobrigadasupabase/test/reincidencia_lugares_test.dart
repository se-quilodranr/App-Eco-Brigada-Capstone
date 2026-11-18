import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/core/reincidencia_lugares.dart';

void main() {
  test('Registra un intervalo entre limpieza y nuevo reporte', () {
    final ubicaciones = <Map<String, dynamic>>[
      {'id': 'zona-a', 'nombre': 'Parque comunitario'},
    ];
    final historial = <Map<String, dynamic>>[
      {'lugar_id':'zona-a','estado_nuevo':'sucio','cambiado_en':'2026-10-01T00:00:00Z'},
      {'lugar_id':'zona-a','estado_nuevo':'limpio','cambiado_en':'2026-10-02T00:00:00Z'},
      {'lugar_id':'zona-a','estado_nuevo':'sucio','cambiado_en':'2026-10-08T00:00:00Z'},
    ];
    final r = analizarReaparicionLugares(historial, ubicaciones);
    expect(r.length, 1);
    expect(r.single.nombre, 'Parque comunitario');
    expect(r.single.dias, 6);
  });
  test('Sin limpieza previa no afirma reincidencia', () {
    expect(analizarReaparicionLugares([
      {'lugar_id':'a','estado_nuevo':'sucio','cambiado_en':'2026-10-08T00:00:00Z'},
    ],[]),isEmpty);
  });
}
