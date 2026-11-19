import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'algorithms.dart';
import 'registro_validacion.dart';
import 'models.dart';
import '../services/photo_service.dart';
import '../services/offline_queue.dart';

/// Estado de la aplicación, respaldado EXCLUSIVAMENTE por Supabase.
/// Ningún rol se modifica desde el cliente. PostgreSQL RLS y RPC son autoridad.
class EcoStore extends ChangeNotifier {
  EcoStore({SupabaseClient? client, ReportQueue? queue})
    : _db = client ?? Supabase.instance.client,
      cola = queue ?? ReportQueue();
  final SupabaseClient _db;
  final ReportQueue cola;
  final List<StreamSubscription<dynamic>> _subs = [];
  late final EcoPhotoService fotos = EcoPhotoService(_db);

  List<Reporte> reportes = [];
  List<Brigada> brigadas = [];
  Set<String> brigadasSinCoordenadas = {};
  List<Jornada> jornadas = [];
  List<Movimiento> movimientos = [];
  List<SolicitudBrigada> solicitudes = [];
  List<IntegranteBrigada> integrantes = [];
  List<PuntoReciclaje> puntosReciclaje = [];
  // Lugares y cambios de estado del proyecto Supabase anterior.
  List<Map<String, dynamic>> lugaresOriginales = [];
  List<Map<String, dynamic>> historialLugares = [];
  List<Map<String, dynamic>> notificaciones = [];
  List<Map<String, dynamic>> validaciones = [];
  List<Map<String, dynamic>> fotosReporte = [];
  int pendientesSinConexion = 0;
  String rol = 'ciudadano';
  String nombrePerfil = '';
  String? avatarPath;
  bool listo = false;
  bool sincronizando = false;
  String? aviso;

  User? get usuario => _db.auth.currentUser;
  String get uid => usuario?.id ?? '';
  bool get autenticado => usuario != null;
  bool get esAdmin => rol == 'admin' && autenticado;
  bool get esBrigadista =>
      autenticado && brigadas.any((b) => b.liderUid == uid);
  String get nombreUsuario => nombrePerfil.isNotEmpty
      ? nombrePerfil
      : (usuario?.userMetadata?['nombre']?.toString() ??
            usuario?.email ??
            'Visitante');
  bool gestionaBrigada(String brigadaId) =>
      esAdmin || brigadas.any((b) => b.id == brigadaId && b.liderUid == uid);
  bool soyIntegrante(String brigadaId) =>
      integrantes.any((m) => m.brigadaId == brigadaId && m.uid == uid);
  bool puedeChatear(String brigadaId) =>
      autenticado && (gestionaBrigada(brigadaId) || soyIntegrante(brigadaId));
  SolicitudBrigada? miSolicitud(String brigadaId) {
    for (final s in solicitudes) {
      if (s.brigadaId == brigadaId && s.uid == uid) return s;
    }
    return null;
  }

  List<SolicitudBrigada> solicitudesDe(String brigadaId) =>
      solicitudes.where((s) => s.brigadaId == brigadaId).toList()
        ..sort((a, b) => b.fechaSolicitud.compareTo(a.fechaSolicitud));
  List<IntegranteBrigada> integrantesDe(String brigadaId) =>
      integrantes.where((e) => e.brigadaId == brigadaId).toList();
  int get pendientes => reportes.where((r) => r.estado == 'pendiente').length;
  int get cerrados => reportes.where((r) => r.estado == 'cerrado').length;
  int get activos => reportes.where((r) => r.abierto).length;
  List<Reporte> get recientes =>
      [...reportes]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  List<Movimiento> historialDe(String reporteId) =>
      movimientos.where((m) => m.reporteId == reporteId).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
  List<Map<String, dynamic>> evidenciasDe(String id) =>
      fotosReporte.where((m) => m['reporte_id'] == id).toList();
  List<Map<String, dynamic>> validacionesDe(String id) =>
      validaciones.where((m) => m['reporte_id'] == id).toList();

  static String _str(dynamic d) => d?.toString() ?? '';
  static Map<String, dynamic> _reporte(Map<String, dynamic> d) => {
    ...d,
    'creadorUid': d['creador_uid'],
    'brigadaId': d['brigada_id'] ?? '',
    'creadoEn': d['creado_en'],
    'actualizadoEn': d['actualizado_en'],
    'cerradoEn': d['cerrado_en'],
  };
  static Brigada _brigada(Map<String, dynamic> d) => Brigada.fromJson({
    ...d,
    'liderUid': d['lider_uid'] ?? '',
    'miembros': d['miembros'] ?? 0,
  });
  static Jornada _jornada(Map<String, dynamic> d) => Jornada.fromJson({
    ...d,
    'brigadaId': d['brigada_id'] ?? '',
    'fecha': d['fecha_inicio'],
    'lugar': d['descripcion'] ?? d['titulo'],
  });
  static SolicitudBrigada _solicitud(Map<String, dynamic> d) =>
      SolicitudBrigada.fromJson({
        'uid': d['usuario_id'],
        'brigadaId': d['brigada_id'],
        'nombre':
            (d['perfiles'] is Map ? d['perfiles']['nombre'] : null) ??
            'Solicitante',
        'estado': d['estado'] == 'aceptada' ? 'aprobada' : d['estado'],
        'revisadoPor': d['revisada_por'] ?? '',
        'fechaSolicitud': d['enviada_en'],
        'fechaDecision': d['revisada_en'],
      });
  static IntegranteBrigada _integrante(Map<String, dynamic> d) =>
      IntegranteBrigada.fromJson({
        'uid': d['usuario_id'],
        'brigadaId': d['brigada_id'],
        'nombre':
            (d['perfiles'] is Map ? d['perfiles']['nombre'] : null) ??
            'Integrante',
        'fechaIngreso': d['unido_en'],
      });
  static Movimiento _mov(Map<String, dynamic> d) => Movimiento.fromJson({
    'id': d['id'],
    'reporteId': d['reporte_id'],
    'anterior': d['anterior'],
    'nuevo': d['nuevo'],
    'autorUid': d['autor_uid'],
    'comentario': d['comentario'],
    'fecha': d['fecha'],
  });
  static MensajeBrigada _msg(Map<String, dynamic> d) =>
      MensajeBrigada.fromJson({
        'id': d['id'],
        'brigadaId': d['brigada_id'],
        'autorUid': d['autor_id'],
        'autorNombre': d['nombre'] ?? 'Integrante',
        'texto': d['texto'],
        'fecha': d['enviado_en'],
      });

  String _lastSessionUid = '';
  Future<void> iniciar() async {
    _lastSessionUid = uid;
    _subs.add(
      _db.auth.onAuthStateChange.listen(
        (state) {
          final newUid = state.session?.user.id ?? '';
          if (_lastSessionUid == newUid) return;
          _lastSessionUid = newUid;
          // Cambios de cuenta borran datos ajenos inmediatamente.
          _limpiar();
          _notiSub?.cancel();
          _notiSub = null;
          _notiUid = '';
          _incSub?.cancel();
          _incSub = null;
          if (newUid.isNotEmpty) {
            refrescar();
          } else {
            notifyListeners();
          }
        },
        onError: (Object e) {
          aviso = 'No fue posible validar la sesión: $e';
          notifyListeners();
        },
      ),
    );
    pendientesSinConexion = (await cola.leer()).length;
    if (autenticado) await refrescar();
    listo = true;
    notifyListeners();
  }

  void _limpiar() {
    reportes = [];
    brigadas = [];
    brigadasSinCoordenadas = {};
    jornadas = [];
    movimientos = [];
    solicitudes = [];
    integrantes = [];
    notificaciones = [];
    validaciones = [];
    fotosReporte = [];
    puntosReciclaje = [];
    lugaresOriginales = [];
    historialLugares = [];
    nombrePerfil = '';
    rol = 'ciudadano';
    avatarPath = null;
    aviso = null;
    notifyListeners();
  }

  // PostgREST limita el tamaño de cada página; lectura en dos bloques.
  // No sustituye la paginación incremental para un despliegue masivo.
  Future<List<Map<String, dynamic>>> _listarReportes() async {
    final total = <Map<String, dynamic>>[];
    for (final page in [0, 1]) {
      final start = page * 1000;
      final end = page == 0 ? 999 : 1499;
      final rows = await _db
          .from('incidencias')
          .select()
          .order('creado_en', ascending: false)
          .range(start, end);
      total.addAll(rows.map((e) => Map<String, dynamic>.from(e)));
      if (rows.length < (end - start + 1)) break;
    }
    return total;
  }

  Future<void> refrescar() async {
    if (!autenticado) return;
    try {
      final results = await Future.wait<dynamic>([
        _db
            .from('perfiles')
            .select('id,nombre,role,avatar_path')
            .eq('id', uid)
            .single(),
        _listarReportes(),
        _db.from('brigadas').select().order('nombre').limit(300),
        _db
            .from('actividades')
            .select('id,titulo,brigada_id,descripcion,fecha_inicio,estado')
            .order('fecha_inicio')
            .limit(300),
        _db
            .from('brigada_miembros')
            .select('brigada_id,usuario_id,unido_en,perfiles(nombre)')
            .limit(2000),
        _db
            .from('solicitudes')
            .select(
              'id,brigada_id,usuario_id,estado,enviada_en,revisada_en,revisada_por,perfiles!solicitudes_usuario_id_fkey(nombre)',
            )
            .isFilter('actividad_id', null)
            .limit(2000),
        _db.from('puntos_reciclaje').select().limit(300),
        _db
            .from('notificaciones')
            .select()
            .eq('destinatario_uid', uid)
            .order('creada_en', ascending: false)
            .limit(80),
        _db
            .from('lugares')
            .select(
              'id,nombre,descripcion,latitud,longitud,estado,actualizado_en',
            )
            .order('actualizado_en', ascending: false)
            .limit(1000),
        _db
            .from('lugar_historial')
            .select('lugar_id,estado_anterior,estado_nuevo,cambiado_en')
            .order('cambiado_en', ascending: false)
            .limit(2000),
      ]);
      final profile = Map<String, dynamic>.from(results[0] as Map);
      nombrePerfil = _str(profile['nombre']);
      rol = _str(profile['role']);
      avatarPath = profile['avatar_path'] as String?;
      reportes = (results[1] as List)
          .map(
            (e) =>
                Reporte.fromJson(_reporte(Map<String, dynamic>.from(e as Map))),
          )
          .toList();
      brigadasSinCoordenadas = (results[2] as List)
          .where((e) => e['lat'] == null || e['lng'] == null)
          .map((e) => '${e['id']}')
          .toSet();
      brigadas = (results[2] as List)
          .map((e) => _brigada(Map<String, dynamic>.from(e as Map)))
          .toList();
      jornadas = (results[3] as List)
          .map((e) => _jornada(Map<String, dynamic>.from(e as Map)))
          .toList();
      integrantes = (results[4] as List)
          .map((e) => _integrante(Map<String, dynamic>.from(e as Map)))
          .toList();
      solicitudes = (results[5] as List)
          .map((e) => _solicitud(Map<String, dynamic>.from(e as Map)))
          .toList();
      puntosReciclaje = (results[6] as List)
          .map(
            (e) => PuntoReciclaje.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      notificaciones = (results[7] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      lugaresOriginales = (results[8] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      historialLugares = (results[9] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      pendientesSinConexion = (await cola.leer()).length;
      aviso = null;
      notifyListeners();
      // Un listener para el feed personal. Renovar solo al cambiar de identidad.
      _escucharNotificaciones();
      _escucharIncidencias();
      await reenviarPendientes();
    } catch (e) {
      aviso = 'No se pudieron consultar los datos: $e';
      notifyListeners();
    }
  }

  StreamSubscription<dynamic>? _notiSub;
  StreamSubscription<dynamic>? _incSub;
  void _escucharIncidencias() {
    if (_incSub != null || !autenticado) return;
    final sesion = uid;
    _incSub = _db
        .from('incidencias')
        .stream(primaryKey: ['id'])
        .listen(
          (_) {
            if (uid == sesion) refrescarSinPendientes();
          },
          onError: (Object e) {
            if (uid == sesion) {
              aviso = 'Actualización de incidencias: $e';
              notifyListeners();
            }
          },
        );
  }

  String _notiUid = '';
  void _escucharNotificaciones() {
    if (_notiUid == uid && _notiSub != null) return;
    _notiSub?.cancel();
    _notiUid = uid;
    _notiSub = _db
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .eq('destinatario_uid', uid)
        .order('creada_en', ascending: false)
        .limit(80)
        .listen(
          (data) {
            notificaciones = data
                .map((d) => Map<String, dynamic>.from(d))
                .toList();
            notifyListeners();
          },
          onError: (Object e) {
            aviso = 'Notificaciones: $e';
            notifyListeners();
          },
        );
  }

  Future<void> acceder(String correo, String password) async {
    await _db.auth.signInWithPassword(email: correo.trim(), password: password);
  }

  Future<void> registrar({
    required String correo,
    required String password,
  }) async {
    // Validación también al llamar al servicio sin pasar por el formulario.
    if (RegistroValidacion.correo(correo) != null ||
        RegistroValidacion.contrasena(password) != null) {
      throw ArgumentError('Revisa tu correo y contraseña.');
    }
    // Supabase Auth gestiona las credenciales. El trigger crea el perfil.
    final res = await _db.auth.signUp(email: correo.trim(), password: password);
    if (res.session == null) {
      throw StateError(
        'Cuenta creada. Verifica tu correo y después inicia sesión.',
      );
    }
  }

  Future<void> salir() async {
    await _db.auth.signOut();
    _notiSub?.cancel();
    _notiSub = null;
    _notiUid = '';
    _limpiar();
  }

  Future<String> crearReporte({
    required String titulo,
    required String descripcion,
    required String tipo,
    required String direccion,
    required String comuna,
    required LatLng punto,
    required int gravedad,
    XFile? fotoInicial,
  }) async {
    if (!autenticado) throw StateError('Inicia sesión.');
    if (titulo.trim().length < 5 ||
        descripcion.trim().length < 10 ||
        direccion.trim().length < 3 ||
        comuna.trim().length < 3) {
      throw ArgumentError('Completa título, descripción, dirección y comuna.');
    }
    final datos = <String, dynamic>{
      'id': const Uuid().v4(),
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'tipo': tipo,
      'direccion': direccion.trim(),
      'comuna': comuna.trim(),
      'lat': punto.latitude,
      'lng': punto.longitude,
      'gravedad': gravedad,
      'creador_uid': uid,
    };
    Uint8List? foto;
    if (fotoInicial != null) foto = await fotos.preparar(fotoInicial);
    try {
      return await _crearRemoto(datos, foto);
    } catch (e) {
      if (_errorConexion(e)) {
        await _encolar(datos, foto);
        return 'pendiente-local';
      }
      rethrow;
    }
  }

  bool _errorConexion(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('socketexception') ||
        t.contains('failed host lookup') ||
        t.contains('network request failed') ||
        t.contains('failed to fetch') ||
        t.contains('clientexception') ||
        t.contains('connection refused');
  }

  Future<void> _encolar(Map<String, dynamic> datos, Uint8List? foto) async {
    await cola.agregar({
      ...datos,
      'localId': crearId(),
      'usuario': uid,
      'imagenBase64': foto == null ? '' : base64Encode(foto),
    });
    pendientesSinConexion = (await cola.leer()).length;
    notifyListeners();
  }

  Future<String> _crearRemoto(
    Map<String, dynamic> datos,
    Uint8List? imagen,
  ) async {
    final id = datos['id'].toString();
    try {
      await _db.from('incidencias').insert(datos).select('id').single();
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      // Reintentos idempotentes tras pérdida de conectividad/respuesta.
      final exists = await _db
          .from('incidencias')
          .select('id,creador_uid')
          .eq('id', id)
          .eq('creador_uid', uid)
          .maybeSingle();
      if (exists == null) rethrow;
    }
    if (imagen != null) {
      try {
        await subirBytesReporte(id, 'inicial', imagen);
      } catch (e) {
        aviso = 'Reporte creado, pero la foto no pudo subirse: $e';
        notifyListeners();
      }
    }
    await refrescarSinPendientes();
    return id;
  }

  Future<void> refrescarSinPendientes() async {
    if (!autenticado) return;
    try {
      final data = await _listarReportes();
      reportes = data
          .map((e) => Reporte.fromJson(_reporte(Map<String, dynamic>.from(e))))
          .toList();
      notifyListeners();
    } catch (e) {
      aviso = 'No se pudieron actualizar los reportes: $e';
      notifyListeners();
    }
  }

  Future<void> reenviarPendientes() async {
    if (sincronizando || !autenticado) return;
    sincronizando = true;
    notifyListeners();
    try {
      final items = await cola.leer();
      for (final item in items) {
        if (item['usuario'] != uid) {
          continue; // Sin enviar datos con otra identidad.
        }
        final datos = Map<String, dynamic>.from(item)
          ..remove('localId')
          ..remove('usuario')
          ..remove('imagenBase64');
        try {
          final imageBase64 = _str(item['imagenBase64']);
          final imagen = imageBase64.isEmpty
              ? null
              : Uint8List.fromList(base64Decode(imageBase64));
          await _crearRemoto(datos, imagen);
          await cola.quitar(_str(item['localId']));
        } catch (e) {
          aviso = 'Existen reportes pendientes de sincronización: $e';
          break;
        }
      }
    } finally {
      pendientesSinConexion = (await cola.leer()).length;
      sincronizando = false;
      notifyListeners();
    }
  }

  Future<void> subirBytesReporte(
    String reporteId,
    String fase,
    Uint8List bytes,
  ) async {
    if (!autenticado) throw StateError('Debes iniciar sesión.');
    final ruta = 'incidencias/$reporteId/$fase/$uid/${crearId()}.jpg';
    await fotos.subirBytes(bytes, ruta);
    await _db.from('fotos_incidencia').insert({
      'reporte_id': reporteId,
      'autor_uid': uid,
      'fase': fase,
      'storage_path': ruta,
    });
    await cargarEvidencias(reporteId);
  }

  Future<void> subirFotoReporte(
    String reporteId,
    String fase,
    XFile foto,
  ) async => subirBytesReporte(reporteId, fase, await fotos.preparar(foto));
  Future<void> cargarEvidencias(String reporteId) async {
    final fotos = await _db
        .from('fotos_incidencia')
        .select()
        .eq('reporte_id', reporteId)
        .order('creado_en');
    fotosReporte.removeWhere((r) => r['reporte_id'] == reporteId);
    fotosReporte.addAll(fotos.map((e) => Map<String, dynamic>.from(e)));
    final rows = await _db
        .from('validaciones_limpieza')
        .select()
        .eq('reporte_id', reporteId)
        .order('fecha', ascending: false);
    validaciones.removeWhere((r) => r['reporte_id'] == reporteId);
    validaciones.addAll(rows.map((e) => Map<String, dynamic>.from(e)));
    notifyListeners();
  }

  Future<void> actualizarAvatar(XFile imagen) async {
    if (!autenticado) throw StateError('Inicia sesión.');
    final path = 'perfiles/$uid/${crearId()}.jpg';
    await fotos.subirBytes(await fotos.preparar(imagen), path);
    await _db.from('perfiles').update({'avatar_path': path}).eq('id', uid);
    avatarPath = path;
    notifyListeners();
  }

  Future<void> cambiarEstado(
    Reporte r,
    String nuevo, {
    String brigadaId = '',
    String comentario = '',
  }) async {
    if (!transicionValida(r.estado, nuevo)) {
      throw StateError('Transición inválida.');
    }
    await _db.rpc(
      'cambiar_estado_reporte',
      params: {
        'p_id': r.id,
        'p_nuevo': nuevo,
        'p_brigada': brigadaId.isEmpty ? null : brigadaId,
        'p_comentario': comentario.trim(),
      },
    );
    await refrescarSinPendientes();
    await cargarHistorial(r.id);
    await cargarEvidencias(r.id);
  }

  Future<void> tomarIncidencia(String id, {String? brigadaId}) async {
    await _db.rpc(
      'tomar_incidencia',
      params: {'p_id': id, 'p_brigada': brigadaId},
    );
    await refrescarSinPendientes();
    await cargarHistorial(id);
    await cargarEvidencias(id);
  }

  Future<void> terminarIncidencia(String id) async {
    await _db.rpc('terminar_incidencia', params: {'p_id': id});
    await refrescarSinPendientes();
    await cargarHistorial(id);
  }

  Future<void> crearBrigada({
    required String nombre,
    required String comuna,
    required String descripcion,
    required int miembros,
    required LatLng punto,
    String? liderUid,
  }) async {
    if (!esAdmin) throw StateError('Solo administración puede crear brigadas.');
    await _db.from('brigadas').insert({
      'nombre': nombre.trim(),
      'comuna': comuna.trim(),
      'descripcion': descripcion.trim(),
      'lat': punto.latitude,
      'lng': punto.longitude,
      'creador_id': uid,
      'estado': 'abierta',
      'lider_uid': liderUid == null || liderUid.trim().isEmpty
          ? uid
          : liderUid.trim(),
    });
    await refrescar();
  }

  Future<void> cargarParticipacion(String brigadaId) async {
    if (!autenticado) return;
    final results = await Future.wait<dynamic>([
      _db
          .from('solicitudes')
          .select(
            'id,brigada_id,usuario_id,estado,enviada_en,revisada_en,revisada_por,perfiles!solicitudes_usuario_id_fkey(nombre)',
          )
          .eq('brigada_id', brigadaId)
          .isFilter('actividad_id', null),
      _db
          .from('brigada_miembros')
          .select('brigada_id,usuario_id,unido_en,perfiles(nombre)')
          .eq('brigada_id', brigadaId),
    ]);
    solicitudes.removeWhere((e) => e.brigadaId == brigadaId);
    integrantes.removeWhere((e) => e.brigadaId == brigadaId);
    solicitudes.addAll(
      (results[0] as List).map(
        (e) => _solicitud(Map<String, dynamic>.from(e as Map)),
      ),
    );
    integrantes.addAll(
      (results[1] as List).map(
        (e) => _integrante(Map<String, dynamic>.from(e as Map)),
      ),
    );
    notifyListeners();
  }

  Future<void> solicitarIngreso(String brigadaId) async {
    await _db.rpc(
      'enviar_solicitud',
      params: {'p_brigada': brigadaId, 'p_actividad': null, 'p_mensaje': ''},
    );
    await cargarParticipacion(brigadaId);
  }

  Future<void> revisarSolicitud(
    SolicitudBrigada solicitud, {
    required bool aprobar,
  }) async {
    // La tabla original usa solicitudes UUID, no un identificador compuesto.
    // Solo revisamos solicitudes de ingreso a la BRIGADA (actividad_id IS NULL).
    final pending = await _db
        .from('solicitudes')
        .select('id')
        .eq('brigada_id', solicitud.brigadaId)
        .eq('usuario_id', solicitud.uid)
        .eq('estado', 'pendiente')
        .isFilter('actividad_id', null)
        .limit(1);
    if (pending.isEmpty) throw StateError('La solicitud ya no está pendiente.');
    await _db.rpc(
      'eco_resolver_solicitud',
      params: {'p_solicitud': pending.first['id'], 'p_aceptar': aprobar},
    );
    await cargarParticipacion(solicitud.brigadaId);
    await refrescar();
  }

  Future<void> cambiarEstadoJornada(
    String jornadaId,
    String nuevoEstado,
  ) async {
    if (!['programada', 'en_curso', 'finalizada'].contains(nuevoEstado)) {
      throw StateError('Estado de actividad inválido.');
    }

    final jornada = jornadas.firstWhere((j) => j.id == jornadaId);

    if (!gestionaBrigada(jornada.brigadaId)) {
      throw StateError('No tienes permiso para gestionar esta actividad.');
    }

    await _db
        .from('actividades')
        .update({'estado': nuevoEstado})
        .eq('id', jornadaId);

    await refrescar();
  }

  Future<void> crearJornada({
    required String titulo,
    required String brigadaId,
    required String lugar,
    required DateTime fecha,
  }) async {
    if (!gestionaBrigada(brigadaId)) {
      throw StateError('No puedes organizar esta brigada.');
    }
    if (brigadasSinCoordenadas.contains(brigadaId)) {
      throw StateError('Esta brigada aún no tiene coordenadas verificadas.');
    }
    final b = brigadas.firstWhere((b) => b.id == brigadaId);
    await _db.from('actividades').insert({
      'titulo': titulo.trim(),
      'brigada_id': brigadaId,
      'descripcion': lugar.trim(),
      'latitud': b.lat,
      'longitud': b.lng,
      'fecha_inicio': fecha.toUtc().toIso8601String(),
    });
    await refrescar();
  }

  Future<void> cargarHistorial(String reporteId) async {
    final rows = await _db
        .from('historial_incidencias')
        .select()
        .eq('reporte_id', reporteId)
        .order('fecha', ascending: false)
        .limit(120);
    movimientos.removeWhere((e) => e.reporteId == reporteId);
    movimientos.addAll(rows.map((e) => _mov(Map<String, dynamic>.from(e))));
    notifyListeners();
  }

  Stream<List<MensajeBrigada>> escucharMensajes(String brigadaId) {
    if (!puedeChatear(brigadaId)) {
      return Stream.error(StateError('Sin acceso al chat'));
    }
    return _db
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('brigada_id', brigadaId)
        .order('enviado_en', ascending: false)
        .limit(100)
        .map(
          (rows) => rows
              .map((e) {
                final autor = e['autor_id'];
                String nombre = 'Integrante';
                for (final miembro in integrantes) {
                  if (miembro.uid == autor) {
                    nombre = miembro.nombre;
                    break;
                  }
                }
                return _msg({
                  ...Map<String, dynamic>.from(e),
                  'nombre': nombre,
                });
              })
              .toList()
              .reversed
              .toList(),
        );
  }

  Future<void> enviarMensaje(String brigadaId, String mensaje) async {
    final texto = mensaje.trim();
    if (!puedeChatear(brigadaId)) {
      throw StateError('No tienes acceso a este chat.');
    }
    if (texto.isEmpty || texto.length > 2000) {
      throw ArgumentError('Mensaje inválido.');
    }
    await _db.from('mensajes').insert({
      'brigada_id': brigadaId,
      'autor_id': uid,
      'texto': texto,
    });
  }

  Future<void> marcarLugarOriginal(String lugarId, String nuevoEstado) async {
    if (!autenticado) {
      throw StateError('Inicia sesión para actualizar el punto.');
    }
    if (nuevoEstado != 'limpio' && nuevoEstado != 'sucio') {
      throw ArgumentError('Estado no reconocido.');
    }
    await _db.rpc(
      'marcar_lugar',
      params: {'p_lugar': lugarId, 'p_estado': nuevoEstado},
    );
    await refrescar();
  }

  Future<void> marcarNotificacion(String id) async {
    await _db
        .from('notificaciones')
        .update({'leida_en': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('destinatario_uid', uid);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _notiSub?.cancel();
    _incSub?.cancel();
    super.dispose();
  }
}
