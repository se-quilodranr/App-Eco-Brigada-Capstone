class PasoEnsamblaje {
  final int numero;
  final String instruccion;

  PasoEnsamblaje({
    required this.numero,
    required this.instruccion,
  });
}

class GuiaEnsamblaje {
  final String id;
  final String titulo;
  final List<String> materiales;
  final List<PasoEnsamblaje> pasos;

  GuiaEnsamblaje({
    required this.id,
    required this.titulo,
    required this.materiales,
    required this.pasos,
  });

  factory GuiaEnsamblaje.desdePublicacion(
    Map<String, dynamic> publicacion,
  ) {
    final textoMateriales =
        publicacion['materiales']?.toString() ?? '';

    final materiales = textoMateriales
        .split(RegExp(r'[,;\n]+'))
        .map((material) => material.trim())
        .where((material) => material.isNotEmpty)
        .toList();

    final pasos = <PasoEnsamblaje>[];

    final datosPasos = publicacion['publicacion_pasos'];

    if (datosPasos is List) {
      for (final paso in datosPasos) {
        if (paso is! Map) continue;

        final numero =
            int.tryParse(paso['numero'].toString());

        final texto =
            paso['texto']?.toString().trim() ?? '';

        if (numero == null || texto.isEmpty) continue;

        pasos.add(
          PasoEnsamblaje(
            numero: numero,
            instruccion: texto,
          ),
        );
      }
    }

    pasos.sort((a, b) => a.numero.compareTo(b.numero));

    return GuiaEnsamblaje(
      id: publicacion['id']?.toString() ?? '',
      titulo: publicacion['titulo']?.toString() ?? '',
      materiales: materiales,
      pasos: pasos,
    );
  }

  bool get puedeAnalizarse =>
      materiales.isNotEmpty && pasos.isNotEmpty;
}