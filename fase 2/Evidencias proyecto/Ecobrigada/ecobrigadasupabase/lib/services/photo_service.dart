import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compresión compatible con Flutter Web y Android, sin rutas de disco.
/// Se preserva solo JPG, no EXIF GPS, para reducir exposición accidental.
class EcoPhotoService {
  final SupabaseClient db;
  EcoPhotoService(this.db);
  static const bucket = 'eco-evidencias';

  Future<Uint8List> preparar(XFile imagen) async {
    final raw = await imagen.readAsBytes();
    if (raw.length > 15 * 1024 * 1024) {
      throw StateError('La imagen original supera 15 MB.');
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw StateError('Formato de imagen no compatible.');
    final maxDim = decoded.width > decoded.height ? decoded.width : decoded.height;
    final copy = maxDim > 1280 ? img.copyResize(decoded,
      width: decoded.width >= decoded.height ? 1280 : null,
      height: decoded.height > decoded.width ? 1280 : null) : decoded;
    final data = Uint8List.fromList(img.encodeJpg(copy, quality: 72));
    if (data.length > 5 * 1024 * 1024) {
      throw StateError('La fotografía comprimida supera 5 MB.');
    }
    return data;
  }

  Future<String> subirBytes(Uint8List bytes, String ruta) async {
    await db.storage.from(bucket).uploadBinary(ruta, bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    return ruta;
  }

  Future<String> urlTemporal(String ruta, {int segundos=600}) =>
      db.storage.from(bucket).createSignedUrl(ruta, segundos);
}
