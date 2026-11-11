import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Requiere flutter_local_notifications 19.5.0 (API con argumentos posicionales).
class AlertasCercanas {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;
  bool _permitido = false;

  Future<bool> solicitarPermiso() async {
    if (!Platform.isAndroid) return false;

    if (!_inicializado) {
      const opciones = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(opciones);
      _inicializado = true;
    }

    _permitido = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    return _permitido;
  }

  Future<void> mostrarAviso({
    required String id,
    required String titulo,
    required String categoria,
    required double distanciaKm,
  }) async {
    if (!_permitido || !_inicializado || !Platform.isAndroid) return;

    const detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'eco_puntos_cercanos',
        'Puntos cercanos EcoBrigada',
        channelDescription: 'Avisos de iniciativas ecológicas próximas',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.show(
      id.hashCode & 0x7FFFFFFF,
      'EcoBrigada · $categoria',
      '$titulo está a ${distanciaKm.toStringAsFixed(1)} km de ti.',
      detalles,
    );
  }
}
