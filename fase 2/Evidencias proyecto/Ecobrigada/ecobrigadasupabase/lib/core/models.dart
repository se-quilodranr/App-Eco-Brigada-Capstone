import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Elimina marcas de carga inicial de la PRESENTACIÓN. No modifica Supabase.
/// Las filas de demostración conservan sus datos originales y sus IDs.
String etiquetaVisible(String texto) {
  return texto
      .replaceAll(RegExp(r'\[\s*FICTICIO(?:\s+QA-31)?\s*\]\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(\s*fictici[oa]s?\s*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\b(?:ficticio|ficticia|ficticios|ficticias)\b', caseSensitive: false), '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
}

const estadosReporte = [
  'pendiente', 'validado', 'asignado', 'en_proceso', 'en_revision', 'cerrado', 'descartado',
];

String estadoNombre(String value) => switch (value) {
  'pendiente' => 'Pendiente',
  'validado' => 'Validado',
  'asignado' => 'Asignado',
  'en_proceso' => 'En ejecución',
  'en_revision' => 'En revisión',
  'cerrado' => 'Cerrado',
  'descartado' => 'Descartado',
  _ => value,
};

const tiposReporte = ['Basura', 'Escombros', 'Microbasural', 'Otro'];

class Reporte {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo;
  final String direccion;
  final String comuna;
  final double lat;
  final double lng;
  final int gravedad;
  final int prioridad;
  final String estado;
  final String creadorUid;
  final String brigadaId;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final DateTime? cerradoEn;

  const Reporte({
    required this.id, required this.titulo, required this.descripcion,
    required this.tipo, required this.direccion, required this.comuna,
    required this.lat, required this.lng, required this.gravedad,
    required this.prioridad, required this.estado, required this.creadorUid,
    required this.brigadaId, required this.creadoEn, required this.actualizadoEn,
    required this.cerradoEn,
  });

  bool get abierto => estado != 'cerrado' && estado != 'descartado';
  LatLng get punto => LatLng(lat, lng);

  Reporte copyWith({String? estado, String? brigadaId, DateTime? actualizadoEn,
    DateTime? cerradoEn, int? prioridad}) => Reporte(
      id: id, titulo: titulo, descripcion: descripcion, tipo: tipo,
      direccion: direccion, comuna: comuna, lat: lat, lng: lng,
      gravedad: gravedad, prioridad: prioridad ?? this.prioridad,
      estado: estado ?? this.estado, creadorUid: creadorUid,
      brigadaId: brigadaId ?? this.brigadaId,
      creadoEn: creadoEn, actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      cerradoEn: cerradoEn ?? this.cerradoEn,
    );

  Map<String, dynamic> toJson() => {
    'id': id, 'titulo': titulo, 'descripcion': descripcion, 'tipo': tipo,
    'direccion': direccion, 'comuna': comuna, 'lat': lat, 'lng': lng,
    'gravedad': gravedad, 'prioridad': prioridad, 'estado': estado,
    'creadorUid': creadorUid, 'brigadaId': brigadaId,
    'creadoEn': creadoEn.toIso8601String(),
    'actualizadoEn': actualizadoEn.toIso8601String(),
    'cerradoEn': cerradoEn?.toIso8601String(),
  };

  factory Reporte.fromJson(Map<String, dynamic> d) => Reporte(
    id: '${d['id'] ?? ''}', titulo: etiquetaVisible('${d['titulo'] ?? ''}'),
    descripcion: etiquetaVisible('${d['descripcion'] ?? ''}'), tipo: '${d['tipo'] ?? 'Otro'}',
    direccion: '${d['direccion'] ?? ''}', comuna: '${d['comuna'] ?? ''}',
    lat: (d['lat'] as num?)?.toDouble() ?? -36.827,
    lng: (d['lng'] as num?)?.toDouble() ?? -73.050,
    gravedad: (d['gravedad'] as num?)?.toInt() ?? 1,
    prioridad: (d['prioridad'] as num?)?.toInt() ?? 20,
    estado: '${d['estado'] ?? 'pendiente'}',
    creadorUid: '${d['creadorUid'] ?? ''}',
    brigadaId: '${d['brigadaId'] ?? ''}',
    creadoEn: DateTime.tryParse('${d['creadoEn']}') ?? DateTime.now(),
    actualizadoEn: DateTime.tryParse('${d['actualizadoEn']}') ?? DateTime.now(),
    cerradoEn: DateTime.tryParse('${d['cerradoEn']}'),
  );
}

class Brigada {
  final String id, nombre, descripcion, comuna, liderUid;
  final double lat, lng;
  final int miembros;
  final bool disponible;
  const Brigada({required this.id, required this.nombre, required this.descripcion,
    required this.comuna, required this.liderUid, required this.lat,
    required this.lng, required this.miembros, required this.disponible});
  LatLng get punto => LatLng(lat, lng);
  Map<String, dynamic> toJson() => {
    'id': id, 'nombre': nombre, 'descripcion': descripcion, 'comuna': comuna,
    'liderUid': liderUid, 'lat': lat, 'lng': lng,
    'miembros': miembros, 'disponible': disponible,
  };
  factory Brigada.fromJson(Map<String, dynamic> d) => Brigada(
    id: '${d['id'] ?? ''}', nombre: etiquetaVisible('${d['nombre'] ?? ''}'),
    descripcion: etiquetaVisible('${d['descripcion'] ?? ''}'), comuna: '${d['comuna'] ?? ''}',
    liderUid: '${d['liderUid'] ?? ''}',
    lat: (d['lat'] as num?)?.toDouble() ?? -36.827,
    lng: (d['lng'] as num?)?.toDouble() ?? -73.050,
    miembros: (d['miembros'] as num?)?.toInt() ?? 0,
    disponible: d['disponible'] == true,
  );
}

class Jornada {
  final String id, titulo, brigadaId, lugar, estado;
  final DateTime fecha;
  const Jornada({required this.id, required this.titulo,
    required this.brigadaId, required this.lugar, required this.fecha,
    this.estado = 'programada'});
  Map<String, dynamic> toJson() => {
    'id': id, 'titulo': titulo, 'brigadaId': brigadaId,
    'lugar': lugar, 'fecha': fecha.toIso8601String(), 'estado': estado,
  };
  factory Jornada.fromJson(Map<String, dynamic> d) => Jornada(
    id: '${d['id'] ?? ''}', titulo: etiquetaVisible('${d['titulo'] ?? ''}'),
    brigadaId: '${d['brigadaId'] ?? ''}', lugar: etiquetaVisible('${d['lugar'] ?? ''}'), estado: '${d['estado'] ?? 'programada'}',
    fecha: DateTime.tryParse('${d['fecha']}') ?? DateTime.now(),
  );
}

class Movimiento {
  final String id, reporteId, anterior, nuevo, autorUid, comentario;
  final DateTime fecha;
  const Movimiento({required this.id, required this.reporteId,
    required this.anterior, required this.nuevo, required this.autorUid,
    required this.comentario, required this.fecha});
  Map<String, dynamic> toJson() => {
    'id': id, 'reporteId': reporteId, 'anterior': anterior, 'nuevo': nuevo,
    'autorUid': autorUid, 'comentario': comentario, 'fecha': fecha.toIso8601String(),
  };
  factory Movimiento.fromJson(Map<String, dynamic> d) => Movimiento(
    id: '${d['id'] ?? ''}', reporteId: '${d['reporteId'] ?? ''}',
    anterior: '${d['anterior'] ?? ''}', nuevo: '${d['nuevo'] ?? ''}',
    autorUid: '${d['autorUid'] ?? ''}', comentario: etiquetaVisible('${d['comentario'] ?? ''}'),
    fecha: DateTime.tryParse('${d['fecha']}') ?? DateTime.now(),
  );
}

const ecoCentro = LatLng(-36.8270, -73.0503);

String crearId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';


/// Solicitud de incorporación registrada por un ciudadano.
class SolicitudBrigada {
  final String uid, brigadaId, nombre, estado, revisadoPor;
  final DateTime fechaSolicitud;
  final DateTime? fechaDecision;

  const SolicitudBrigada({required this.uid, required this.brigadaId,
    required this.nombre, required this.estado, required this.revisadoPor,
    required this.fechaSolicitud, required this.fechaDecision});

  Map<String, dynamic> toJson() => {
    'uid': uid, 'brigadaId': brigadaId, 'nombre': nombre,
    'estado': estado, 'revisadoPor': revisadoPor,
    'fechaSolicitud': fechaSolicitud.toIso8601String(),
    'fechaDecision': fechaDecision?.toIso8601String(),
  };

  factory SolicitudBrigada.fromJson(Map<String, dynamic> d) => SolicitudBrigada(
    uid: '${d['uid'] ?? ''}', brigadaId: '${d['brigadaId'] ?? ''}',
    nombre: '${d['nombre'] ?? ''}', estado: '${d['estado'] ?? 'pendiente'}',
    revisadoPor: '${d['revisadoPor'] ?? ''}',
    fechaSolicitud: DateTime.tryParse('${d['fechaSolicitud']}') ?? DateTime.now(),
    fechaDecision: DateTime.tryParse('${d['fechaDecision']}'),
  );

  SolicitudBrigada copyWith({String? estado, String? revisadoPor,
    DateTime? fechaDecision, DateTime? fechaSolicitud}) => SolicitudBrigada(
      uid: uid, brigadaId: brigadaId, nombre: nombre,
      estado: estado ?? this.estado, revisadoPor: revisadoPor ?? this.revisadoPor,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      fechaDecision: fechaDecision,
    );
}

/// Integrante confirmado por un líder de la brigada o un administrador.
class IntegranteBrigada {
  final String uid, brigadaId, nombre;
  final DateTime fechaIngreso;
  const IntegranteBrigada({required this.uid, required this.brigadaId,
    required this.nombre, required this.fechaIngreso});

  Map<String, dynamic> toJson() => {
    'uid': uid, 'brigadaId': brigadaId, 'nombre': nombre,
    'fechaIngreso': fechaIngreso.toIso8601String(),
  };
  factory IntegranteBrigada.fromJson(Map<String, dynamic> d) => IntegranteBrigada(
    uid: '${d['uid'] ?? ''}', brigadaId: '${d['brigadaId'] ?? ''}',
    nombre: '${d['nombre'] ?? ''}',
    fechaIngreso: DateTime.tryParse('${d['fechaIngreso']}') ?? DateTime.now(),
  );
}


/// Mensajes persistidos en public.mensajes_brigada y protegidos con RLS.
class MensajeBrigada {
  final String id, brigadaId, autorUid, autorNombre, texto;
  final DateTime fecha;

  const MensajeBrigada({required this.id, required this.brigadaId,
    required this.autorUid, required this.autorNombre, required this.texto,
    required this.fecha});

  Map<String, dynamic> toJson() => {
    'id': id, 'brigadaId': brigadaId, 'autorUid': autorUid,
    'autorNombre': autorNombre, 'texto': texto,
    'fecha': fecha.toIso8601String(),
  };

  factory MensajeBrigada.fromJson(Map<String, dynamic> d) => MensajeBrigada(
    id: '${d['id'] ?? ''}', brigadaId: '${d['brigadaId'] ?? ''}',
    autorUid: '${d['autorUid'] ?? ''}',
    autorNombre: etiquetaVisible('${d['autorNombre'] ?? 'Integrante'}'),
    texto: etiquetaVisible('${d['texto'] ?? ''}'),
    fecha: DateTime.tryParse('${d['fecha']}') ?? DateTime.now(),
  );
}

/// Marcador de reciclaje verificado en el backend.
class PuntoReciclaje {
  final String id, nombre, descripcion, comuna;
  final double lat, lng;
  const PuntoReciclaje({required this.id, required this.nombre,
    required this.descripcion, required this.comuna,
    required this.lat, required this.lng});

  LatLng get punto => LatLng(lat, lng);
  Map<String, dynamic> toJson() => {
    'id': id, 'nombre': nombre, 'descripcion': descripcion,
    'comuna': comuna, 'lat': lat, 'lng': lng,
  };
  factory PuntoReciclaje.fromJson(Map<String, dynamic> d) =>
      PuntoReciclaje(id: '${d['id'] ?? ''}', nombre: etiquetaVisible('${d['nombre'] ?? ''}'),
        descripcion: etiquetaVisible('${d['descripcion'] ?? ''}'), comuna: '${d['comuna'] ?? ''}',
        lat: (d['lat'] as num?)?.toDouble() ?? 0,
        lng: (d['lng'] as num?)?.toDouble() ?? 0);
}
