import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/ensamblaje/guia_ensamblaje.dart';
import 'package:ecobrigadasupabase/ensamblaje/catalogo_materiales.dart';
import 'package:ecobrigadasupabase/ensamblaje/interpretador_guia.dart';
import 'package:ecobrigadasupabase/ensamblaje/interpretador_acciones.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Interpretar una guía completa', () async {
    final catalogo = await CatalogoMateriales.cargar();

    final guia = GuiaEnsamblaje.desdePublicacion({
      'id': '1',
      'titulo': 'Macetero reciclado',
      'materiales': 'Base de botella, tierra, planta, cuerda',
      'publicacion_pasos': [
        {
          'numero': 1,
          'texto': 'Agregar tierra en la base de botella',
        },
        {
          'numero': 2,
          'texto': 'Colocar una planta',
        },
      ],
    });

    final resultado =
        InterpretadorGuia(catalogo).interpretar(guia);

    expect(resultado.materiales.length, 3);
    expect(resultado.pasos.length, 2);
    expect(resultado.materialesNoReconocidos, ['cuerda']);

    expect(
      resultado.pasos.first.acciones,
      [AccionEnsamblaje.agregar],
    );

    expect(
      resultado.pasos.last.acciones,
      [AccionEnsamblaje.colocar],
    );
  });
}