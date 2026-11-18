import 'catalogo_materiales.dart';

class InterpretadorMateriales {
  final List<Material3D> catalogo;

  InterpretadorMateriales(this.catalogo);

  String normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Material3D? buscarMaterial(String texto) {
    final textoNormalizado = ' ${normalizar(texto)} ';

    Material3D? resultado;
    int mayorCoincidencia = 0;

    for (final material in catalogo) {
      for (final palabra in material.palabrasClave) {
        final clave = normalizar(palabra);

        if (clave.isEmpty) continue;

        if (textoNormalizado.contains(' $clave ') &&
            clave.length > mayorCoincidencia) {
          resultado = material;
          mayorCoincidencia = clave.length;
        }
      }
    }

    return resultado;
  }

  List<Material3D> buscarMateriales(String texto) {
    final palabras = normalizar(texto).split(' ');
    final encontrados = <Material3D>[];

    int indice = 0;

    while (indice < palabras.length) {
      final frase = palabras.skip(indice).join(' ');

      Material3D? mejorMaterial;
      int longitud = 0;

      for (final material in catalogo) {
        for (final palabra in material.palabrasClave) {
          final clave = normalizar(palabra);

          if (clave.isEmpty) continue;

          final cantidad = clave.split(' ').length;

          if ((frase == clave || frase.startsWith('$clave ')) &&
              cantidad > longitud) {
            mejorMaterial = material;
            longitud = cantidad;
          }
        }
      }

      if (mejorMaterial != null) {
        if (!encontrados.any((m) => m.id == mejorMaterial!.id)) {
          encontrados.add(mejorMaterial);
        }

        indice += longitud;
      } else {
        indice++;
      }
    }

    return encontrados;
  }
}
