import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ecobrigadasupabase/core/algorithms.dart';
import 'package:ecobrigadasupabase/core/models.dart';

void main() {
  test('Prioridad: mayor gravedad eleva el puntaje', () {
    expect(calcularPrioridad(gravedad: 5, diasAbierto: 3, reportesCercanos: 1),
      greaterThan(calcularPrioridad(gravedad: 2, diasAbierto: 3, reportesCercanos: 1)));
  });
  test('Los valores se mantienen de 0 a 100', () {
    expect(calcularPrioridad(gravedad: 5, diasAbierto: 400, reportesCercanos: 50), 100);
  });
  test('No se permite cerrar directamente un pendiente', () {
    expect(transicionValida('pendiente', 'cerrado'), isFalse);
    expect(transicionValida('pendiente', 'validado'), isTrue);
  });
  test('EcoRadar identifica coincidencias cercanas del mismo tipo', () {
    final ahora = DateTime(2026, 11, 13);
    final reportes = [Reporte(id: '1', titulo: 'Bolsa', descripcion: 'basura',
      tipo: 'Basura', direccion: 'X', comuna: 'Concepción', lat: -36.8270,
      lng: -73.05, gravedad: 2, prioridad: 30, estado: 'pendiente',
      creadorUid: 'u', brigadaId: '', creadoEn: ahora,
      actualizadoEn: ahora, cerradoEn: null)];
    expect(buscarDuplicados(posicion: const LatLng(-36.8271, -73.0501),
      tipo: 'Basura', reportes: reportes).length, 1);
    expect(buscarDuplicados(posicion: const LatLng(-36.8271, -73.0501),
      tipo: 'Escombros', reportes: reportes), isEmpty);
  });
  test('EcoMatch favorece equipos cercanos disponibles', () {
    final r = Reporte(id: 'r', titulo: 'A', descripcion: 'B', tipo: 'Basura',
      direccion: 'C', comuna: 'Concepción', lat: -36.827, lng: -73.05,
      gravedad: 2, prioridad: 50, estado: 'validado', creadorUid: 'u',
      brigadaId: '', creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(), cerradoEn: null);
    const equipos = [
      Brigada(id: '1', nombre: 'Cercana', descripcion: '', comuna: '',
        liderUid: '', lat: -36.827, lng: -73.050, miembros: 8, disponible: true),
      Brigada(id: '2', nombre: 'Lejana', descripcion: '', comuna: '',
        liderUid: '', lat: -37.0, lng: -73.4, miembros: 8, disponible: true),
      Brigada(id: '3', nombre: 'No disponible', descripcion: '', comuna: '',
        liderUid: '', lat: -36.827, lng: -73.050, miembros: 20, disponible: false),
    ];
    final ranking = recomendarBrigadas(r, equipos, [r]);
    expect(ranking.first.brigada.id, '1');
    expect(ranking.length, 2);
  });
  test('CSV escapa correctamente las comillas', () {
    expect(campoCsv('a"b'), '"a""b"');
  });
}
