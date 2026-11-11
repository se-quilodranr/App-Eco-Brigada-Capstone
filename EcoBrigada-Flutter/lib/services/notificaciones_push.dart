import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Preparación opt-in para recibir push Android con FCM.
/// No solicita permisos al abrir el mapa. Los envíos vienen de un backend seguro.
/// Guarda la ULTIMA posición consentida; no sigue al usuario en segundo plano.
class NotificacionesPush {
  static final NotificacionesPush _instancia = NotificacionesPush._();
  factory NotificacionesPush() => _instancia;
  NotificacionesPush._();

  StreamSubscription<String>? _renovacionToken;
  double? _lat;
  double? _lon;
  double? _radioKm;

  bool get disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> activar({required double lat, required double lon, required double radioKm}) async {
    if (!disponible) return false;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return false;

    final messaging = FirebaseMessaging.instance;
    final permiso = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (permiso.authorizationStatus != AuthorizationStatus.authorized &&
        permiso.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    _lat = lat;
    _lon = lon;
    _radioKm = radioKm;
    final token = await messaging.getToken();
    if (token == null) return false;
    await _guardarToken(usuario.uid, token);
    await _renovacionToken?.cancel();
    _renovacionToken = messaging.onTokenRefresh.listen((nuevo) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && _lat != null) await _guardarToken(uid, nuevo);
    });
    return true;
  }

  Future<void> _guardarToken(String uid, String token) async {
    final id = sha256.convert(token.codeUnits).toString();
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('dispositivos')
        .doc(id)
        .set({
      'token': token,
      'ubicacion': GeoPoint(_lat!, _lon!),
      'radioKm': _radioKm!,
      'plataforma': 'android',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// El usuario puede retirar el permiso desde Android o eliminar sus tokens
  /// usando esta función desde una pantalla de privacidad.
  Future<void> desactivar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      final id = sha256.convert(token.codeUnits).toString();
      await FirebaseFirestore.instance
          .collection('usuarios').doc(uid).collection('dispositivos').doc(id).delete();
    }
    await _renovacionToken?.cancel();
    _renovacionToken = null;
  }
}
