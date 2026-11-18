class Posicion3D {
  final double x;
  final double y;
  final double z;

  const Posicion3D(this.x, this.y, this.z);
}

class Pieza3D {
  final String id;
  final String materialId;
  final Posicion3D posicion;
  final double escala;

  const Pieza3D({
    required this.id,
    required this.materialId,
    required this.posicion,
    this.escala = 1.0,
  });
}

class EscenaEnsamblaje {
  final int numeroPaso;
  final String instruccion;
  final List<Pieza3D> piezas;

  const EscenaEnsamblaje({
    required this.numeroPaso,
    required this.instruccion,
    required this.piezas,
  });
}