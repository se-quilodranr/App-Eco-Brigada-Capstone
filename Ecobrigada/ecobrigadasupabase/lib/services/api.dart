import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Api {
  static SupabaseClient get db => Supabase.instance.client;
  static String get uid {
    final id = db.auth.currentUser?.id;
    if (id == null) throw StateError('Primero debes iniciar sesión.');
    return id;
  }

  static Future<bool> registrarse(
    String nombre,
    String correo,
    String clave,
  ) async {
    final r = await db.auth.signUp(
      email: correo.trim(),
      password: clave,
      data: {'nombre': nombre.trim()},
    );
    return r.session != null;
  }

  static Future<void> ingresar(String correo, String clave) async {
    await db.auth.signInWithPassword(email: correo.trim(), password: clave);
  }

  static Future<void> salir() => db.auth.signOut();

  static Future<Map<String, dynamic>?> perfil() async {
    if (db.auth.currentUser == null) return null;
    return await db.from('perfiles').select().eq('id', uid).maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> brigadas() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('brigadas')
            .select('*,perfiles(nombre)')
            .order('creada_en', ascending: false),
      );

  static Future<String> crearBrigada({
    required String nombre,
    required String comuna,
    required String descripcion,
    required String estado,
  }) async {
    final row = await db
        .from('brigadas')
        .insert({
          'nombre': nombre.trim(),
          'comuna': comuna.trim(),
          'descripcion': descripcion.trim(),
          'estado': estado,
          'creador_id': uid,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<void> cambiarEstadoBrigada(String id, String estado) =>
      db.from('brigadas').update({'estado': estado}).eq('id', id).then((_) {});

  static Future<List<Map<String, dynamic>>> miembros(String brigadaId) async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('brigada_miembros')
            .select('usuario_id,rol,perfiles(nombre)')
            .eq('brigada_id', brigadaId),
      );

  static Future<bool> soyMiembro(String brigadaId) async =>
      (await db.rpc('soy_miembro', params: {'p_brigada': brigadaId})) == true;

  static Future<List<Map<String, dynamic>>> actividades({
    String? brigadaId,
  }) async {
    var q = db
        .from('actividades')
        .select('*,brigadas(nombre,estado,creador_id)');
    if (brigadaId != null) q = q.eq('brigada_id', brigadaId);
    return List<Map<String, dynamic>>.from(
      await q.order('fecha_inicio', ascending: true),
    );
  }

  static Future<String> crearActividad({
    required String brigadaId,
    required String titulo,
    required String descripcion,
    required double lat,
    required double lon,
    required DateTime inicio,
  }) async {
    final row = await db
        .from('actividades')
        .insert({
          'brigada_id': brigadaId,
          'titulo': titulo.trim(),
          'descripcion': descripcion.trim(),
          'latitud': lat,
          'longitud': lon,
          'fecha_inicio': inicio.toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<void> cambiarEstadoActividad(String id, String estado) async {
    await db.from('actividades').update({'estado': estado}).eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> solicitudesBrigada(
    String brigadaId,
  ) async => List<Map<String, dynamic>>.from(
    await db
        .from('solicitudes')
        .select(
          '*,perfiles!solicitudes_usuario_id_fkey(nombre),actividades(titulo)',
        )
        .eq('brigada_id', brigadaId)
        .order('enviada_en', ascending: false),
  );

  static Future<List<Map<String, dynamic>>> misSolicitudes() async {
    if (db.auth.currentUser == null) return [];
    return List<Map<String, dynamic>>.from(
      await db
          .from('solicitudes')
          .select('*,brigadas(nombre),actividades(titulo)')
          .eq('usuario_id', uid)
          .order('enviada_en', ascending: false),
    );
  }

  static Future<void> solicitar({
    required String brigadaId,
    String? actividadId,
  }) async {
    await db.rpc(
      'enviar_solicitud',
      params: {
        'p_brigada': brigadaId,
        'p_actividad': actividadId,
        'p_mensaje': '',
      },
    );
  }

  static Future<void> resolver(String solicitudId, bool aceptar) async {
    await db.rpc(
      'resolver_solicitud',
      params: {'p_solicitud': solicitudId, 'p_aceptar': aceptar},
    );
  }

  static Stream<List<Map<String, dynamic>>> chat(String brigadaId) => db
      .from('mensajes')
      .stream(primaryKey: ['id'])
      .eq('brigada_id', brigadaId)
      .order('enviado_en', ascending: true);

  static Future<void> enviarMensaje(String brigadaId, String texto) async {
    final value = texto.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError('El mensaje debe tener entre 1 y 2000 caracteres.');
    }
    await db.from('mensajes').insert({
      'brigada_id': brigadaId,
      'autor_id': uid,
      'texto': value,
    });
  }

  static Future<List<Map<String, dynamic>>> lugares() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('lugares')
            .select()
            .order('actualizado_en', ascending: false),
      );

  static Future<void> crearLugar({
    required String nombre,
    required String descripcion,
    required double lat,
    required double lon,
    required String estado,
  }) async {
    await db.from('lugares').insert({
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'latitud': lat,
      'longitud': lon,
      'estado': estado,
      'creado_por': uid,
    });
  }

  static Future<void> marcarLugar(String lugarId, String estado) async {
    await db.rpc(
      'marcar_lugar',
      params: {'p_lugar': lugarId, 'p_estado': estado},
    );
  }

  static Future<List<Map<String, dynamic>>> historialLugar(
    String lugarId,
  ) async => List<Map<String, dynamic>>.from(
    await db
        .from('lugar_historial')
        .select('estado_anterior,estado_nuevo,cambiado_en,perfiles(nombre)')
        .eq('lugar_id', lugarId)
        .order('cambiado_en', ascending: false),
  );

  static Future<List<Map<String, dynamic>>> publicaciones() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('publicaciones')
            .select(
              'id,titulo,descripcion,materiales,creada_en,autor_id,perfiles(nombre),publicacion_fotos(ruta_storage,posicion),publicacion_pasos(numero,texto),publicacion_likes(usuario_id)',
            )
            .eq('estado', 'publicada')
            .order('creada_en', ascending: false)
            .limit(80),
      );

  static Future<void> crearPublicacion({
    required String titulo,
    required String descripcion,
    required String materiales,
    required List<String> pasos,
    required List<XFile> fotos,
  }) async {
    if (titulo.trim().length < 3 ||
        pasos.isEmpty ||
        pasos.length > 12 ||
        fotos.length > 3) {
      throw ArgumentError('Título, pasos o fotografías no válidos.');
    }
    final post = await db
        .from('publicaciones')
        .insert({
          'autor_id': uid,
          'titulo': titulo.trim(),
          'descripcion': descripcion.trim(),
          'materiales': materiales.trim(),
        })
        .select('id')
        .single();
    final id = post['id'] as String;
    await db.from('publicacion_pasos').insert([
      for (var i = 0; i < pasos.length; i++)
        {'publicacion_id': id, 'numero': i + 1, 'texto': pasos[i].trim()},
    ]);
    for (var i = 0; i < fotos.length; i++) {
      final f = fotos[i];
      final data = await f.readAsBytes();
      if (data.length > 5 * 1024 * 1024) {
        throw StateError('La imagen ${i + 1} excede 5 MB.');
      }
      final ext = f.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        throw StateError('Usa imágenes JPG, PNG o WebP.');
      }
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      final path = '$uid/$id/foto_$i.$ext';
      await db.storage
          .from('publicaciones')
          .uploadBinary(
            path,
            data,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      await db.from('publicacion_fotos').insert({
        'publicacion_id': id,
        'ruta_storage': path,
        'posicion': i,
      });
    }
    // Solo se muestra en el feed cuando finalizó toda la subida.
    await db.from('publicaciones').update({'estado': 'publicada'}).eq('id', id);
  }

  static String urlFoto(String ruta) =>
      db.storage.from('publicaciones').getPublicUrl(ruta);

  static Future<void> alternarLike(String publicacionId) async {
    final existe = await db
        .from('publicacion_likes')
        .select('usuario_id')
        .eq('publicacion_id', publicacionId)
        .eq('usuario_id', uid)
        .maybeSingle();
    if (existe == null) {
      await db.from('publicacion_likes').insert({
        'publicacion_id': publicacionId,
        'usuario_id': uid,
      });
    } else {
      await db
          .from('publicacion_likes')
          .delete()
          .eq('publicacion_id', publicacionId)
          .eq('usuario_id', uid);
    }
  }

  static Future<List<Map<String, dynamic>>> comentarios(String postId) async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('comentarios')
            .select('texto,creado_en,perfiles(nombre)')
            .eq('publicacion_id', postId)
            .order('creado_en', ascending: true),
      );

  static Future<void> comentar(String postId, String texto) async {
    if (texto.trim().isEmpty) throw ArgumentError('Escribe un comentario.');
    await db.from('comentarios').insert({
      'publicacion_id': postId,
      'autor_id': uid,
      'texto': texto.trim(),
    });
  }

  static Future<void> reportar(String postId, String motivo) async {
    await db.from('reportes').insert({
      'publicacion_id': postId,
      'reportador_id': uid,
      'motivo': motivo,
    });
  }
}
