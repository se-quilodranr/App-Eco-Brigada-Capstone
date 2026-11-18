import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cola local de operaciones de creación de reporte.
/// No se usa para simular backend ni autoridad de roles.
/// Importante: dispositivos compartidos requieren políticas de limpieza del navegador.
class ReportQueue {
  final SharedPreferencesAsync prefs;
  ReportQueue({SharedPreferencesAsync? prefs}) : prefs = prefs ?? SharedPreferencesAsync();
  static const clave = 'eco_pendientes_v3';
  static const maxItems = 8;

  Future<List<Map<String,dynamic>>> leer() async {
    final raw = await prefs.getString(clave);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<void> agregar(Map<String,dynamic> item) async {
    final list=await leer();
    if (list.length>=maxItems) throw StateError('Tienes $maxItems reportes pendientes. Sincronízalos antes de continuar.');
    final imagen = '${item['imagenBase64'] ?? ''}';
    if (imagen.length>700000) throw StateError('La foto supera el límite local. Intenta una imagen más pequeña con conexión.');
    list.add(item);
    await prefs.setString(clave,jsonEncode(list));
  }
  Future<void> quitar(String id) async {
    final list=await leer();
    list.removeWhere((x)=>x['localId']==id);
    await prefs.setString(clave,jsonEncode(list));
  }
  Future<void> vaciar() async => prefs.remove(clave);
}
