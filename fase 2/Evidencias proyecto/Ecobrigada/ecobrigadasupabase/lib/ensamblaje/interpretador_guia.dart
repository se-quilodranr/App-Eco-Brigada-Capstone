import 'guia_ensamblaje.dart';
import 'catalogo_materiales.dart';
import 'interpretador_materiales.dart';
import 'interpretador_acciones.dart';

class PasoInterpretado {
  final int numero;
  final String instruccion;
  final List<Material3D> materiales;
  final List<AccionEnsamblaje> acciones;

  PasoInterpretado({
    required this.numero,
    required this.instruccion,
    required this.materiales,
    required this.acciones,
  });
}

class GuiaInterpretada {
  final GuiaEnsamblaje guiaOriginal;
  final List<Material3D> materiales;
  final List<String> materialesNoReconocidos;
  final List<PasoInterpretado> pasos;

  GuiaInterpretada({
    required this.guiaOriginal,
    required this.materiales,
    required this.materialesNoReconocidos,
    required this.pasos,
  });
}

class InterpretadorGuia {
  final InterpretadorMateriales interpretadorMateriales;
  final InterpretadorAcciones interpretadorAcciones;

  InterpretadorGuia(List<Material3D> catalogo)
      : interpretadorMateriales =
            InterpretadorMateriales(catalogo),
        interpretadorAcciones = InterpretadorAcciones();

  GuiaInterpretada interpretar(GuiaEnsamblaje guia) {
    final materiales = <String, Material3D>{};
    final desconocidos = <String>[];
    final pasos = <PasoInterpretado>[];

    for (final texto in guia.materiales) {
      final encontrados =
          interpretadorMateriales.buscarMateriales(texto);

      if (encontrados.isEmpty) {
        desconocidos.add(texto);
      }

      for (final material in encontrados) {
        materiales[material.id] = material;
      }
    }

    for (final paso in guia.pasos) {
      pasos.add(
        PasoInterpretado(
          numero: paso.numero,
          instruccion: paso.instruccion,
          materiales: interpretadorMateriales
              .buscarMateriales(paso.instruccion),
          acciones: interpretadorAcciones
              .buscarAcciones(paso.instruccion),
        ),
      );
    }

    return GuiaInterpretada(
      guiaOriginal: guia,
      materiales: materiales.values.toList(),
      materialesNoReconocidos: desconocidos,
      pasos: pasos,
    );
  }
}