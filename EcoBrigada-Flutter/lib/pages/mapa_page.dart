import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/zona_critica.dart';
import 'impacto_page.dart';
import 'qr_punto_page.dart';
import '../services/notificaciones_push.dart';

import '../services/alertas_cercanas.dart';

// Cuatro categorías que usa el mapa comunitario.
enum TipoPunto { reciclaje, sucio, brigada, limpiado }

extension DatosTipoPunto on TipoPunto {
  String get etiqueta => switch (this) {
    TipoPunto.reciclaje => 'Reciclaje',
    TipoPunto.sucio => 'Punto sucio',
    TipoPunto.brigada => 'Brigada',
    TipoPunto.limpiado => 'Punto limpiado',
  };

  Color get color => switch (this) {
    TipoPunto.reciclaje => const Color(0xFF16845C),
    TipoPunto.sucio => const Color(0xFFD88720),
    TipoPunto.brigada => const Color(0xFF287BC4),
    TipoPunto.limpiado => const Color(0xFF7E5BC7),
  };

  IconData get icono => switch (this) {
    TipoPunto.reciclaje => Icons.recycling,
    TipoPunto.sucio => Icons.delete_outline,
    TipoPunto.brigada => Icons.groups,
    TipoPunto.limpiado => Icons.check_circle_outline,
  };
}

class PuntoEco {
  final String id;
  final String nombre;
  final String descripcion;
  final String direccion;
  final TipoPunto tipo;
  final LatLng ubicacion;
  final String creadorUid;
  final String liderNombre;
  final String liderFotoUrl;
  final int cantidadParticipantes;

  const PuntoEco({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.direccion,
    required this.tipo,
    required this.ubicacion,
    required this.creadorUid,
    required this.liderNombre,
    required this.liderFotoUrl,
    required this.cantidadParticipantes,
  });

  factory PuntoEco.desdeDocumento(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const FormatException(
        'El documento de Firestore no contiene datos',
      );
    }
    final gps = data['ubicacion'] as GeoPoint;
    final tipo = TipoPunto.values.firstWhere(
      (element) => element.name == data['tipo'],
      orElse: () => TipoPunto.sucio,
    );

    return PuntoEco(
      id: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      descripcion: (data['descripcion'] ?? '').toString(),
      direccion: (data['direccion'] ?? '').toString(),
      tipo: tipo,
      ubicacion: LatLng(gps.latitude, gps.longitude),
      creadorUid: (data['creadorUid'] ?? '').toString(),
      liderNombre: (data['liderNombre'] ?? '').toString(),
      liderFotoUrl: (data['liderFotoUrl'] ?? '').toString(),
      cantidadParticipantes: (data['cantidadParticipantes'] is num)
          ? (data['cantidadParticipantes'] as num).toInt()
          : 0,
    );
  }
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final _mapController = MapController();
  final _alertas = AlertasCercanas();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _puntosSubscription;
  StreamSubscription<Position>? _ubicacionSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _zonasSubscription;

  // Centro inicial de referencia; se reemplaza por GPS si el usuario acepta.
  static const _centroInicial = LatLng(-36.8270, -73.0498);
  static const _verde = Color(0xFF21865A);

  List<PuntoEco> _puntos = [];
  List<ZonaCritica> _zonas = [];
  bool _verZonas = true;
  LatLng? _miUbicacion;
  bool _cargandoUbicacion = false;
  bool _seleccionandoEnMapa = false;
  bool _alertasActivadas = false;
  bool _revisandoAlertas = false;
  double _radioKm = 5;
  String? _errorFirestore;
  final Set<String> _idsAvisados = {};

  @override
  void initState() {
    super.initState();
    _recuperarRadio();
    _escucharPuntos();
    _escucharZonas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _obtenerUbicacion();
    });
  }

  @override
  void dispose() {
    _puntosSubscription?.cancel();
    _zonasSubscription?.cancel();
    _ubicacionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _recuperarRadio() async {
    final preferencias = await SharedPreferences.getInstance();
    final radio = preferencias.getDouble('radio_mapa_ecobrigada');
    if (!mounted || radio == null) return;
    setState(() => _radioKm = radio.clamp(1.0, 20.0));
    _verificarPuntosCercanos();
  }

  void _escucharPuntos() {
    // Consulta sencilla sin plugins geoespaciales incompatibles.
    // Filtra por kilometraje en el dispositivo (hasta 300 documentos).
    // Para escala mayor, implementar consulta por geohash sin cambiar Firestore.
    _puntosSubscription = FirebaseFirestore.instance
        .collection('puntos_mapa')
        .limit(300)
        .snapshots()
        .listen(
          (snapshot) {
            final puntos = <PuntoEco>[];
            for (final documento in snapshot.docs) {
              try {
                puntos.add(PuntoEco.desdeDocumento(documento));
              } catch (_) {
                // Ignorar temporalmente documentos incompletos o mal formados.
              }
            }
            if (!mounted) return;
            setState(() {
              _puntos = puntos;
              _errorFirestore = null;
            });
            _verificarPuntosCercanos();
          },
          onError: (Object error) {
            if (mounted) setState(() => _errorFirestore = error.toString());
          },
        );
  }

  void _escucharZonas() {
    _zonasSubscription = FirebaseFirestore.instance
        .collection('zonas_criticas')
        .limit(150)
        .snapshots()
        .listen(
          (snapshot) {
            final nuevas = <ZonaCritica>[];
            for (final doc in snapshot.docs) {
              try {
                nuevas.add(ZonaCritica.fromDoc(doc));
              } catch (_) {
                /* Una zona incompleta no debe bloquear el mapa. */
              }
            }
            if (mounted) setState(() => _zonas = nuevas);
          },
          onError: (Object e) {
            if (mounted)
              _mensaje('No se pudieron cargar las zonas críticas: $e');
          },
        );
  }

  void _mostrarZona(ZonaCritica zona) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Zona de concentración de reportes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('${zona.cantidadReportes} reportes sucios cercanos'),
              Text('Prioridad orientativa: ${zona.prioridad}'),
              Text('Radio estimado: ${zona.radioMetros.round()} metros'),
              const SizedBox(height: 10),
              const Text(
                'Detectada con DBSCAN. La prioridad se basa en la cantidad '
                'de reportes, no es una predicción de contaminación.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEscanerQr() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanearPuntoPage()),
    );
    if (id == null || !mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('puntos_mapa')
          .doc(id)
          .get();
      if (!doc.exists) {
        _mensaje('El punto del QR ya no existe.');
        return;
      }
      final punto = PuntoEco.desdeDocumento(doc);
      _mapController.move(punto.ubicacion, 16);
      if (mounted) _mostrarPunto(punto);
    } catch (e) {
      _mensaje('No fue posible abrir el punto: $e');
    }
  }

  Future<void> _desactivarPushCercano() async {
    try {
      await NotificacionesPush().desactivar();
      _mensaje('Preferencias push de este dispositivo eliminadas.');
    } catch (e) {
      _mensaje('No fue posible desactivar las alertas push: $e');
    }
  }

  Future<void> _activarPushCercano() async {
    final origen = _miUbicacion;
    if (origen == null) {
      _mensaje('Primero debes activar tu ubicación.');
      return;
    }
    try {
      final ok = await NotificacionesPush().activar(
        lat: origen.latitude,
        lon: origen.longitude,
        radioKm: _radioKm,
      );
      _mensaje(
        ok
            ? 'Avisos push registrados para Android. Requieren ejecutar el servidor de envíos.'
            : 'Debes iniciar sesión y conceder permiso de notificaciones en Android.',
      );
    } catch (e) {
      _mensaje('No se pudieron activar los avisos push: $e');
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _obtenerUbicacion() async {
    if (_cargandoUbicacion) return false;
    setState(() => _cargandoUbicacion = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _mensaje('Activa la ubicación del dispositivo para usar el GPS.');
        return false;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _mensaje('No se concedió el permiso de ubicación.');
        return false;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return false;
      _actualizarUbicacion(posicion, centrar: true);

      // Actualizamos la posición mientras la pantalla está abierta.
      await _ubicacionSubscription?.cancel();
      _ubicacionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((position) {
            if (mounted) _actualizarUbicacion(position);
          });
      return true;
    } catch (e) {
      _mensaje('No fue posible obtener tu ubicación: $e');
      return false;
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  void _actualizarUbicacion(Position position, {bool centrar = false}) {
    final nueva = LatLng(position.latitude, position.longitude);
    setState(() => _miUbicacion = nueva);
    if (centrar) _mapController.move(nueva, 15);
    _verificarPuntosCercanos();
  }

  double _distanciaKm(LatLng punto) {
    final origen = _miUbicacion;
    if (origen == null) return double.infinity;
    return Geolocator.distanceBetween(
          origen.latitude,
          origen.longitude,
          punto.latitude,
          punto.longitude,
        ) /
        1000;
  }

  List<PuntoEco> get _puntosVisibles => _puntos.where((punto) {
    if (_miUbicacion == null) return true;
    return _distanciaKm(punto.ubicacion) <= _radioKm;
  }).toList();

  Future<void> _habilitarNotificaciones() async {
    final concedido = await _alertas.solicitarPermiso();
    if (!mounted) return;
    setState(() => _alertasActivadas = concedido);
    _mensaje(
      concedido
          ? 'Avisos cercanos activados mientras tengas abierto el mapa.'
          : 'No se activaron las notificaciones de Android.',
    );
    _verificarPuntosCercanos();
  }

  Future<void> _verificarPuntosCercanos() async {
    if (!_alertasActivadas || _miUbicacion == null || _revisandoAlertas) {
      return;
    }
    _revisandoAlertas = true;
    try {
      // Evita una avalancha de notificaciones si ya hay muchos puntos.
      var enviados = 0;
      for (final punto in _puntos) {
        if (_idsAvisados.contains(punto.id)) continue;
        final distancia = _distanciaKm(punto.ubicacion);
        if (distancia > _radioKm) continue;
        _idsAvisados.add(punto.id);
        await _alertas.mostrarAviso(
          id: punto.id,
          titulo: punto.nombre,
          categoria: punto.tipo.etiqueta,
          distanciaKm: distancia,
        );
        enviados++;
        if (enviados >= 3) break;
      }
    } finally {
      _revisandoAlertas = false;
    }
  }

  Future<void> _elegirLugarNuevo() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _mensaje('Inicia sesión para publicar puntos en el mapa.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Dónde agregarás el punto?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.my_location, color: _verde),
                title: const Text('Usar mi ubicación actual'),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (_miUbicacion == null && !await _obtenerUbicacion())
                    return;
                  if (mounted && _miUbicacion != null) {
                    _abrirFormulario(_miUbicacion!);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_location_alt, color: _verde),
                title: const Text('Elegir un lugar en el mapa'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _seleccionandoEnMapa = true);
                  _mensaje('Toca el mapa donde quieras agregar el punto.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFormulario(LatLng ubicacion) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      _mensaje('Debes iniciar sesión.');
      return;
    }

    final nombre = TextEditingController();
    final direccion = TextEditingController();
    final descripcion = TextEditingController();
    final participantes = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    var tipo = TipoPunto.reciclaje;
    var compartirFoto = false;
    var guardando = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (contextoHoja) => StatefulBuilder(
          builder: (contextoHoja, cambiarEstado) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(contextoHoja).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 570),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Publicar punto en el mapa',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TipoPunto>(
                        initialValue: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de punto',
                          border: OutlineInputBorder(),
                        ),
                        items: TipoPunto.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.etiqueta),
                              ),
                            )
                            .toList(),
                        onChanged: guardando
                            ? null
                            : (nuevo) {
                                if (nuevo != null) {
                                  cambiarEstado(() => tipo = nuevo);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nombre,
                        maxLength: 90,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del lugar *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa el nombre'
                            : null,
                      ),
                      TextFormField(
                        controller: direccion,
                        maxLength: 180,
                        decoration: const InputDecoration(
                          labelText: 'Dirección exacta o referencia *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa la dirección'
                            : null,
                      ),
                      TextFormField(
                        controller: descripcion,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Descripción *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Agrega una descripción'
                            : null,
                      ),
                      if (tipo == TipoPunto.brigada) ...[
                        TextFormField(
                          controller: participantes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad de integrantes *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 10000) {
                              return 'Indica entre 1 y 10000 personas';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El creador aparecerá como líder con su nombre y '
                          'apellidos. La cantidad se actualiza manualmente.',
                          style: TextStyle(fontSize: 12),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar mi foto de perfil'),
                          subtitle: const Text(
                            'Si la activas, tu foto será visible para otros '
                            'usuarios que consulten esta brigada.',
                          ),
                          value: compartirFoto,
                          onChanged: guardando
                              ? null
                              : (value) => cambiarEstado(
                                  () => compartirFoto = value ?? false,
                                ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Coordenadas: ${ubicacion.latitude.toStringAsFixed(6)}, '
                        '${ubicacion.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: Text(guardando ? 'Guardando...' : 'Publicar'),
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                cambiarEstado(() => guardando = true);
                                try {
                                  String liderNombre =
                                      usuario.displayName ?? 'Integrante';
                                  String liderFotoUrl = '';
                                  if (tipo == TipoPunto.brigada) {
                                    final perfil = await FirebaseFirestore
                                        .instance
                                        .collection('usuarios')
                                        .doc(usuario.uid)
                                        .get();
                                    final data = perfil.data() ?? {};
                                    final completo =
                                        '${data['nombre'] ?? ''} '
                                                '${data['apellidos'] ?? ''}'
                                            .trim();
                                    if (completo.isNotEmpty) {
                                      liderNombre = completo;
                                    }
                                    // Solo publicar la foto si el creador
                                    // lo autorizó explícitamente.
                                    if (compartirFoto) {
                                      liderFotoUrl = (data['fotoUrl'] ?? '')
                                          .toString();
                                    }
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('puntos_mapa')
                                      .add({
                                        'tipo': tipo.name,
                                        'nombre': nombre.text.trim(),
                                        'direccion': direccion.text.trim(),
                                        'descripcion': descripcion.text.trim(),
                                        'ubicacion': GeoPoint(
                                          ubicacion.latitude,
                                          ubicacion.longitude,
                                        ),
                                        'creadorUid': usuario.uid,
                                        'liderNombre': tipo == TipoPunto.brigada
                                            ? liderNombre
                                            : '',
                                        'liderFotoUrl':
                                            tipo == TipoPunto.brigada
                                            ? liderFotoUrl
                                            : '',
                                        'cantidadParticipantes':
                                            tipo == TipoPunto.brigada
                                            ? int.parse(participantes.text)
                                            : 0,
                                        'creadoEn':
                                            FieldValue.serverTimestamp(),
                                      });
                                  if (!contextoHoja.mounted) return;
                                  Navigator.pop(contextoHoja);
                                  _mensaje('Punto publicado correctamente.');
                                } catch (e) {
                                  if (contextoHoja.mounted) {
                                    ScaffoldMessenger.of(
                                      contextoHoja,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text('No se pudo guardar: $e'),
                                      ),
                                    );
                                    cambiarEstado(() => guardando = false);
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      nombre.dispose();
      direccion.dispose();
      descripcion.dispose();
      participantes.dispose();
    }
  }

  Future<void> _mostrarPunto(PuntoEco punto) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contextoHoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: punto.tipo.color,
                      child: Icon(punto.tipo.icono, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            punto.nombre,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            punto.tipo.etiqueta,
                            style: TextStyle(color: punto.tipo.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Dirección'),
                  subtitle: Text(punto.direccion),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Descripción'),
                  subtitle: Text(punto.descripcion),
                ),
                if (punto.tipo == TipoPunto.brigada) ...[
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: punto.liderFotoUrl.isNotEmpty
                          ? NetworkImage(punto.liderFotoUrl)
                          : null,
                      child: punto.liderFotoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: const Text('Líder de brigada'),
                    subtitle: Text(
                      punto.liderNombre.isEmpty
                          ? 'No especificado'
                          : punto.liderNombre,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Integrantes'),
                    subtitle: Text('${punto.cantidadParticipantes} personas'),
                  ),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Mostrar QR de este punto'),
                  onPressed: () => Navigator.of(contextoHoja).push(
                    MaterialPageRoute(
                      builder: (_) => CodigoQrPuntoPage(
                        puntoId: punto.id,
                        nombre: punto.nombre,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.gps_fixed),
                  title: const Text('Ubicación exacta'),
                  subtitle: Text(
                    '${punto.ubicacion.latitude.toStringAsFixed(6)}, '
                    '${punto.ubicacion.longitude.toStringAsFixed(6)}',
                  ),
                ),
                if (punto.tipo == TipoPunto.sucio &&
                    punto.creadorUid == FirebaseAuth.instance.currentUser?.uid)
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('puntos_mapa')
                            .doc(punto.id)
                            .update({'tipo': TipoPunto.limpiado.name});
                        if (contextoHoja.mounted) Navigator.pop(contextoHoja);
                        _mensaje('Punto marcado como limpiado.');
                      } catch (e) {
                        _mensaje('No fue posible actualizar el punto: $e');
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Marcar como limpiado'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _marcador(PuntoEco punto) => Marker(
    point: punto.ubicacion,
    width: 52,
    height: 52,
    child: Tooltip(
      message: punto.nombre,
      child: InkWell(
        onTap: () => _mostrarPunto(punto),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: punto.tipo.color,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
          ),
          child: Icon(punto.tipo.icono, color: Colors.white),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visibles = _puntosVisibles;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centroInicial,
                  initialZoom: 12.5,
                  minZoom: 4,
                  maxZoom: 19,
                  onTap: (_, coordenadas) {
                    if (!_seleccionandoEnMapa) return;
                    setState(() => _seleccionandoEnMapa = false);
                    _abrirFormulario(coordenadas);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // Usa el ID Android actual de tu proyecto;
                    // actualízalo cuando cambies el applicationId.
                    userAgentPackageName: 'com.example.mi_app',
                  ),
                  if (_verZonas && _zonas.isNotEmpty)
                    CircleLayer(
                      circles: _zonas
                          .map(
                            (zona) => CircleMarker(
                              point: zona.centro,
                              radius: zona.radioMetros,
                              useRadiusInMeter: true,
                              color: Colors.red.withValues(alpha: 0.17),
                              borderColor: Colors.deepOrange,
                              borderStrokeWidth: 2.0,
                            ),
                          )
                          .toList(),
                    ),
                  if (_miUbicacion != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _miUbicacion!,
                          radius: _radioKm * 1000,
                          useRadiusInMeter: true,
                          color: _verde.withValues(alpha: 0.09),
                          borderColor: _verde.withValues(alpha: 0.5),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      ...visibles.map(_marcador),
                      if (_verZonas)
                        ..._zonas.map(
                          (zona) => Marker(
                            point: zona.centro,
                            width: 52,
                            height: 52,
                            child: IconButton.filled(
                              tooltip:
                                  'Zona DBSCAN: ${zona.cantidadReportes} reportes',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                              ),
                              onPressed: () => _mostrarZona(zona),
                              icon: const Icon(Icons.analytics_outlined),
                            ),
                          ),
                        ),
                      if (_miUbicacion != null)
                        Marker(
                          point: _miUbicacion!,
                          width: 27,
                          height: 27,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 7,
                      children: [
                        FilterChip(
                          label: Text('Zonas ML (${_zonas.length})'),
                          avatar: const Icon(
                            Icons.analytics_outlined,
                            size: 17,
                          ),
                          selected: _verZonas,
                          onSelected: (v) => setState(() => _verZonas = v),
                        ),
                        for (final tipo in TipoPunto.values)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tipo.icono, size: 17, color: tipo.color),
                              const SizedBox(width: 4),
                              Text(
                                tipo.etiqueta,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 62,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'gps_ecobrigada',
                      tooltip: 'Centrar en mi ubicación',
                      onPressed: _cargandoUbicacion
                          ? null
                          : () => _obtenerUbicacion(),
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'notificaciones_ecobrigada',
                      tooltip: 'Activar avisos cercanos en Android',
                      onPressed: _habilitarNotificaciones,
                      child: Icon(
                        _alertasActivadas
                            ? Icons.notifications_active
                            : Icons.notifications_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Herramientas del mapa',
                      onSelected: (value) async {
                        if (value == 'estadisticas') {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ImpactoPage(),
                            ),
                          );
                        } else if (value == 'qr') {
                          await _abrirEscanerQr();
                        } else if (value == 'push') {
                          await _activarPushCercano();
                        } else if (value == 'stop_push') {
                          await _desactivarPushCercano();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'estadisticas',
                          child: Text('Estadísticas ambientales'),
                        ),
                        PopupMenuItem(
                          value: 'qr',
                          child: Text('Escanear QR de un punto'),
                        ),
                        PopupMenuItem(
                          value: 'push',
                          child: Text('Activar avisos push (Android)'),
                        ),
                        PopupMenuItem(
                          value: 'stop_push',
                          child: Text('Desactivar avisos push'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'crear_ecobrigada',
                      tooltip: 'Agregar un punto',
                      onPressed: _elegirLugarNuevo,
                      child: const Icon(Icons.add_location_alt),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              if (_seleccionandoEnMapa)
                Positioned(
                  top: 118,
                  left: 12,
                  right: 74,
                  child: Card(
                    color: const Color(0xFFE0F1E7),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Toca el lugar donde crearás el punto'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _seleccionandoEnMapa = false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_errorFirestore != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 36,
                  child: Card(
                    color: const Color(0xFFFFE6E6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Error de Firestore: $_errorFirestore'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Material(
          color: const Color(0xFFF4F8F4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: _verde),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Radio de puntos cercanos')),
                    Text(
                      '${_radioKm.round()} km',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${_radioKm.round()} km',
                  value: _radioKm,
                  onChanged: (value) => setState(() => _radioKm = value),
                  onChangeEnd: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('radio_mapa_ecobrigada', value);
                    _verificarPuntosCercanos();
                  },
                ),
                Text(
                  _miUbicacion == null
                      ? 'Activa tu ubicación para filtrar por distancia.'
                      : '${visibles.length} punto(s) dentro de tu radio.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
