import 'package:ecobrigadasupabase/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los titulos de incidencias no muestran etiquetas de datos demo', () {
    expect(etiquetaVisible('[FICTICIO QA-31] Basura - Collao #6'),
        'Basura - Collao #6');
    expect(etiquetaVisible('[FICTICIO] Jornada ambiental 3'),
        'Jornada ambiental 3');
  });

  test('las brigadas no presentan el sufijo de prueba', () {
    expect(etiquetaVisible('EcoBarrio Collao (ficticia)'),
        'EcoBarrio Collao');
  });

  test('se conservan los nombres y textos autenticos', () {
    expect(etiquetaVisible('Aurora Campos'), 'Aurora Campos');
    expect(etiquetaVisible('Jornada de limpieza en Barrio Norte'),
        'Jornada de limpieza en Barrio Norte');
  });
}
