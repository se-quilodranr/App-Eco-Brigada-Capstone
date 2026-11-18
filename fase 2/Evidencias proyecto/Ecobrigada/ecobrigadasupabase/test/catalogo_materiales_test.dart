import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ecobrigadasupabase/ensamblaje/catalogo_materiales.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Comprobar catálogo y modelos 3D', () async {
    final materiales = await CatalogoMateriales.cargar();

    expect(materiales, isNotEmpty);

    for (final material in materiales) {
      final archivo = await rootBundle.load(material.ruta);

      expect(
        archivo.lengthInBytes,
        greaterThan(0),
        reason: 'Error en el modelo: ${material.ruta}',
      );
    }
  });
}