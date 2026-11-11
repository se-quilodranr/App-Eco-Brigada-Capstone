// Flutter web: el mapa y su filtro de distancia funcionan,
// pero este módulo no emite notificaciones del sistema del navegador.
class AlertasCercanas {
  Future<bool> solicitarPermiso() async => false;

  Future<void> mostrarAviso({
    required String id,
    required String titulo,
    required String categoria,
    required double distanciaKm,
  }) async {}
}
