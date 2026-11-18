/// Evalúa cambios «limpio -> sucio» en la tabla antigua lugar_historial.
/// El tiempo expresa intervalo hasta el NUEVO REGISTRO; no el instante real
/// en que el punto se contaminó nuevamente.
class ReaparicionLugar {
  final String lugarId, nombre;
  final DateTime limpieza, nuevoReporte;
  const ReaparicionLugar(this.lugarId, this.nombre, this.limpieza, this.nuevoReporte);
  Duration get intervalo => nuevoReporte.difference(limpieza);
  int get dias => intervalo.inDays;
}

List<ReaparicionLugar> analizarReaparicionLugares(
  List<Map<String,dynamic>> historial, List<Map<String,dynamic>> lugares,
) {
  final nombres = <String,String>{
    for (final l in lugares) '${l['id']}': '${l['nombre'] ?? 'Lugar'}',
  };
  final grupos = <String,List<Map<String,dynamic>>>{};
  for (final evento in historial) {
    final id = '${evento['lugar_id'] ?? ''}';
    final fecha = DateTime.tryParse('${evento['cambiado_en']}');
    if (id.isEmpty || fecha == null) continue;
    grupos.putIfAbsent(id, () => []).add(evento);
  }
  final encontrados = <ReaparicionLugar>[];
  for (final entrada in grupos.entries) {
    final eventos = entrada.value..sort((a,b) =>
      DateTime.parse('${a['cambiado_en']}').compareTo(DateTime.parse('${b['cambiado_en']}')));
    DateTime? limpieza;
    for (final evento in eventos) {
      final fecha = DateTime.parse('${evento['cambiado_en']}');
      if (evento['estado_nuevo'] == 'limpio') {
        limpieza = fecha;
      } else if (evento['estado_nuevo'] == 'sucio' &&
          limpieza != null && !fecha.isBefore(limpieza)) {
        encontrados.add(ReaparicionLugar(
          entrada.key, nombres[entrada.key] ?? 'Lugar', limpieza, fecha));
        limpieza = null;
      }
    }
  }
  encontrados.sort((a,b) => b.nuevoReporte.compareTo(a.nuevoReporte));
  return encontrados;
}
