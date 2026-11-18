import 'escena_ensamblaje.dart';

class PlantillaMacetero {
  static List<EscenaEnsamblaje> generar() {
    const base = Pieza3D(
      id: 'base_1',
      materialId: 'botella_base',
      posicion: Posicion3D(0, 0, 0),
    );

    const tierra = Pieza3D(
      id: 'tierra_1',
      materialId: 'tierra',
      posicion: Posicion3D(0, 0.012, 0),
    );

    const planta = Pieza3D(
      id: 'planta_1',
      materialId: 'planta',
      posicion: Posicion3D(0, 0.075, 0),
    );

    return const [
      EscenaEnsamblaje(
        numeroPaso: 0,
        instruccion: 'Preparar la base de botella',
        piezas: [base],
      ),
      EscenaEnsamblaje(
        numeroPaso: 1,
        instruccion: 'Agregar la tierra',
        piezas: [base, tierra],
      ),
      EscenaEnsamblaje(
        numeroPaso: 2,
        instruccion: 'Colocar la planta',
        piezas: [base, tierra, planta],
      ),
    ];
  }
}