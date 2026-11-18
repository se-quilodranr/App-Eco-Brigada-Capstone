import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/ensamblaje/interpretador_acciones.dart';

void main() {
  final interpretador = InterpretadorAcciones();

  test('Reconocer una acción', () {
    expect(
      interpretador.buscarAcciones('Cortar el cartón'),
      [AccionEnsamblaje.cortar],
    );
  });

  test('Reconocer varias acciones', () {
    expect(
      interpretador.buscarAcciones(
        'Corta el cartón y pega el papel',
      ),
      [
        AccionEnsamblaje.cortar,
        AccionEnsamblaje.pegar,
      ],
    );
  });

  test('Instrucción desconocida', () {
    expect(
      interpretador.buscarAcciones('Objeto reciclado'),
      isEmpty,
    );
  });
}