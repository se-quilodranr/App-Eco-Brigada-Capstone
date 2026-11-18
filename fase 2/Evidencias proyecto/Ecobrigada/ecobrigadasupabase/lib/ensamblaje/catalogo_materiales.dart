import 'dart:convert';
import 'package:flutter/services.dart';

class Material3D {
  final String id;
  final String nombre;
  final String categoria;
  final List<String> palabrasClave;

  Material3D({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.palabrasClave,
  });

  String get ruta => 'assets/ensamblaje/$id.glb';

  factory Material3D.fromJson(Map<String, dynamic> json) {
    return Material3D(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      palabrasClave: List<String>.from(
        json['palabras_clave'],
      ),
    );
  }
}

class CatalogoMateriales {
  static Future<List<Material3D>> cargar() async {
    final contenido = await rootBundle.loadString(
      'assets/ensamblaje/catalogo.json',
    );

    final List<dynamic> datos = jsonDecode(contenido);

    return datos.map((item) {
      return Material3D.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }
}