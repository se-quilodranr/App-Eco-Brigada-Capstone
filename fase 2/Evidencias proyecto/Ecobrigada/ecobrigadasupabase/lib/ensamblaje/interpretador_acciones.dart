enum AccionEnsamblaje {
  cortar,
  pegar,
  unir,
  rellenar,
  doblar,
  colocar,
  perforar,
  agregar,
  retirar,
  limpiar,
  decorar,
  plantar,
}

class InterpretadorAcciones {
  static const acciones = <String, AccionEnsamblaje>{
    'cortar': AccionEnsamblaje.cortar,
    'corta': AccionEnsamblaje.cortar,
    'recortar': AccionEnsamblaje.cortar,
    'recorta': AccionEnsamblaje.cortar,

    'pegar': AccionEnsamblaje.pegar,
    'pega': AccionEnsamblaje.pegar,

    'unir': AccionEnsamblaje.unir,
    'une': AccionEnsamblaje.unir,
    'ensamblar': AccionEnsamblaje.unir,

    'rellenar': AccionEnsamblaje.rellenar,
    'rellena': AccionEnsamblaje.rellenar,
    'llenar': AccionEnsamblaje.rellenar,

    'doblar': AccionEnsamblaje.doblar,
    'dobla': AccionEnsamblaje.doblar,

    'colocar': AccionEnsamblaje.colocar,
    'coloca': AccionEnsamblaje.colocar,
    'poner': AccionEnsamblaje.colocar,
    'pon': AccionEnsamblaje.colocar,

    'perforar': AccionEnsamblaje.perforar,
    'perfora': AccionEnsamblaje.perforar,

    'agregar': AccionEnsamblaje.agregar,
    'agrega': AccionEnsamblaje.agregar,
    'añadir': AccionEnsamblaje.agregar,
    'añade': AccionEnsamblaje.agregar,

    'retirar': AccionEnsamblaje.retirar,
    'retira': AccionEnsamblaje.retirar,

    'lavar': AccionEnsamblaje.limpiar,
    'lava': AccionEnsamblaje.limpiar,
    'limpiar': AccionEnsamblaje.limpiar,
    'limpia': AccionEnsamblaje.limpiar,

    'decorar': AccionEnsamblaje.decorar,
    'decora': AccionEnsamblaje.decorar,
    'pintar': AccionEnsamblaje.decorar,
    'pinta': AccionEnsamblaje.decorar,

    'plantar': AccionEnsamblaje.plantar,
    
  };

  List<AccionEnsamblaje> buscarAcciones(String texto) {
    final palabras = RegExp(r'[a-záéíóúüñ]+')
        .allMatches(texto.toLowerCase());

    final resultado = <AccionEnsamblaje>[];

    for (final palabra in palabras) {
      final accion = acciones[palabra.group(0)];

      if (accion != null) {
        resultado.add(accion);
      }
    }

    return resultado;
  }
}