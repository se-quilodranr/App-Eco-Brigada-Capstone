import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/ensamblaje/catalogo_materiales.dart';
import 'package:ecobrigadasupabase/ensamblaje/interpretador_materiales.dart';

void main() {
  test('Reconocer varios materiales', () async {
    final catalogo = await CatalogoMateriales.cargar();

    final interpretador = InterpretadorMateriales(catalogo);

    final resultado = interpretador.buscarMateriales(
      'Agregar tierra en la base de botella y colocar una planta',
    );

    expect(resultado.map((m) => m.id).toList(), [
      'tierra',
      'botella_base',
      'planta',
    ]);
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Reconocer materiales de una guía', () async {
    final catalogo = await CatalogoMateriales.cargar();

    final interpretador = InterpretadorMateriales(catalogo);

    expect(interpretador.buscarMaterial('Un trozo de CARTÓN')?.id, 'carton');

    expect(interpretador.buscarMaterial('Agregar tierra')?.id, 'tierra');

    expect(interpretador.buscarMaterial('Colocar una planta')?.id, 'planta');

    expect(interpretador.buscarMaterial('Base de botella')?.id, 'botella_base');

    expect(interpretador.buscarMaterial('Madera'), isNull);
  });
}
