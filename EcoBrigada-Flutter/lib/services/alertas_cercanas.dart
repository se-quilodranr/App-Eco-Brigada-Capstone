// En navegador se usa la implementación de respaldo; en Android/iOS,
// la implementación nativa. No se solicitan permisos al abrir la pantalla.
export 'alertas_cercanas_web.dart'
    if (dart.library.io) 'alertas_cercanas_nativas.dart';
