import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/api.dart';

const centroConcepcion = LatLng(-36.8270, -73.0503);

Future<LatLng> ubicacionActual() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Activa la ubicación de tu dispositivo.');
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied ||
      permiso == LocationPermission.deniedForever) {
    throw StateError('No se concedió permiso para acceder a la ubicación.');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return LatLng(p.latitude, p.longitude);
}

Widget mosaicosMapa() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'cl.ecobrigada.app',
);

Widget creditosMapa() => Align(
  alignment: Alignment.bottomLeft,
  child: Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 6),
    child: Material(
      color: Colors.white.withValues(alpha: .9),
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 10),
          ),
        ),
      ),
    ),
  ),
);

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});
  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final controller = MapController();
  List<Map<String, dynamic>> lugares = [];
  List<Map<String, dynamic>> actividades = [];
  bool cargando = true;
  bool seleccionando = false;
  bool verSucios = true;
  bool verLimpios = true;
  bool verBrigadas = true;
  LatLng? miPosicion;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> recargar() async {
    try {
      final datos = await Future.wait([Api.lugares(), Api.actividades()]);
      if (!mounted) return;
      setState(() {
        lugares = datos[0];
        actividades = datos[1];
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      mostrarError(context, e);
    }
  }

  Future<void> miUbicacion() async {
    try {
      final punto = await ubicacionActual();
      if (mounted) {
        setState(() => miPosicion = punto);
        controller.move(punto, 15);
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> crearLugar(LatLng p) async {
    setState(() => seleccionando = false);
    final nombre = TextEditingController();
    final descripcion = TextEditingController();
    String estado = 'sucio';
    final datos = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Marcar nuevo lugar',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lat: ${p.latitude.toStringAsFixed(5)} · Lon: ${p.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombre,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del lugar',
                  ),
                ),
                TextField(
                  controller: descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  items: const [
                    DropdownMenuItem(
                      value: 'sucio',
                      child: Text('🔴 Lugar sucio'),
                    ),
                    DropdownMenuItem(
                      value: 'limpio',
                      child: Text('🟢 Lugar limpio'),
                    ),
                  ],
                  onChanged: (v) => setSheet(() => estado = v ?? 'sucio'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'nombre': nombre.text,
                    'descripcion': descripcion.text,
                    'estado': estado,
                  }),
                  child: const Text('Guardar ubicación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nombre.dispose();
    descripcion.dispose();
    if (!mounted || datos == null) return;
    if ((datos['nombre'] ?? '').trim().length < 3) {
      mostrarError(context, 'Escribe un nombre de al menos 3 caracteres');
      return;
    }
    try {
      await Api.crearLugar(
        nombre: datos['nombre']!,
        descripcion: datos['descripcion']!,
        lat: p.latitude,
        lon: p.longitude,
        estado: datos['estado']!,
      );
      await recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> detalleLugar(Map<String, dynamic> lugar) async {
    final id = lugar['id'] as String;
    final limpio = lugar['estado'] == 'limpio';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lugar['nombre'].toString(),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(lugar['descripcion']?.toString() ?? ''),
            const SizedBox(height: 12),
            Chip(label: Text(limpio ? '🟢 Limpio' : '🔴 Sucio')),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: Text(limpio ? 'Marcar como sucio' : 'Marcar como limpio'),
              onPressed: () async {
                if (!await asegurarSesion(sheet)) return;
                try {
                  await Api.marcarLugar(id, limpio ? 'sucio' : 'limpio');
                  if (sheet.mounted) Navigator.pop(sheet);
                  await recargar();
                } catch (e) {
                  if (sheet.mounted) mostrarError(sheet, e);
                }
              },
            ),
            TextButton(
              onPressed: () async {
                try {
                  final historial = await Api.historialLugar(id);
                  if (!sheet.mounted) return;
                  await showDialog<void>(
                    context: sheet,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Historial del lugar'),
                      content: SizedBox(
                        width: 400,
                        height: 250,
                        child: ListView(
                          children: [
                            for (final h in historial)
                              ListTile(
                                title: Text('Estado: ${h['estado_nuevo']}'),
                                subtitle: Text(
                                  '${(h['perfiles'] as Map?)?['nombre'] ?? 'Usuario'} · ${h['cambiado_en']}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (sheet.mounted) mostrarError(sheet, e);
                }
              },
              child: const Text('Ver historial de cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> detalleActividad(Map<String, dynamic> act) async {
    final b = (act['brigadas'] as Map?) ?? {};
    final abierta = b['estado'] == 'abierta';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                act['titulo'].toString(),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Brigada: ${b['nombre'] ?? ''}'),
              Text('Actividad: ${act['estado']}'),
              Text(
                'Inicio: ${act['fecha_inicio'].toString().replaceFirst('T', ' ').substring(0, 16)}',
              ),
              const SizedBox(height: 10),
              Text(act['descripcion']?.toString() ?? ''),
              const SizedBox(height: 12),
              Text(
                abierta
                    ? '🟢 Brigada abierta a solicitudes'
                    : '🔒 Brigada cerrada: no recibe solicitudes',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: abierta
                    ? () async {
                        if (!await asegurarSesion(sheet)) return;
                        try {
                          await Api.solicitar(
                            brigadaId: act['brigada_id'] as String,
                            actividadId: act['id'] as String,
                          );
                          if (!sheet.mounted || !mounted) return;
                          Navigator.pop(sheet);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Solicitud enviada. Espera la aprobación del administrador.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (sheet.mounted) mostrarError(sheet, e);
                        }
                      }
                    : null,
                icon: const Icon(Icons.person_add),
                label: Text(
                  abierta ? 'Solicitar participar' : 'Solicitudes cerradas',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final l in lugares) {
      if (l['estado'] == 'sucio' && !verSucios) continue;
      if (l['estado'] == 'limpio' && !verLimpios) continue;
      markers.add(
        Marker(
          point: LatLng(
            (l['latitud'] as num).toDouble(),
            (l['longitud'] as num).toDouble(),
          ),
          width: 54,
          height: 54,
          child: IconButton(
            tooltip: l['nombre'].toString(),
            onPressed: () => detalleLugar(l),
            icon: Icon(
              Icons.location_on,
              size: 44,
              color: l['estado'] == 'sucio'
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ),
        ),
      );
    }

    if (miPosicion != null) {
      markers.add(
        Marker(
          point: miPosicion!,
          width: 34,
          height: 34,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_pin_circle, color: Colors.white, size: 28),
          ),
        ),
      );
    }

    if (verBrigadas) {
      for (final a in actividades) {
        if (a['estado'] == 'finalizada') continue;
        markers.add(
          Marker(
            point: LatLng(
              (a['latitud'] as num).toDouble(),
              (a['longitud'] as num).toDouble(),
            ),
            width: 55,
            height: 55,
            child: IconButton(
              tooltip: 'Actividad: ${a['titulo']}',
              onPressed: () => detalleActividad(a),
              icon: CircleAvatar(
                backgroundColor: a['estado'] == 'en_curso'
                    ? Colors.orange
                    : Colors.blue.shade700,
                child: const Icon(Icons.groups, color: Colors.white),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: centroConcepcion,
            initialZoom: 12.5,
            onTap: (_, point) {
              if (seleccionando) crearLugar(point);
            },
          ),
          children: [
            mosaicosMapa(),
            MarkerLayer(markers: markers),
            creditosMapa(),
          ],
        ),
        Positioned(
          left: 12,
          top: 10,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('🔴 Sucios'),
                    selected: verSucios,
                    onSelected: (v) => setState(() => verSucios = v),
                  ),
                  FilterChip(
                    label: const Text('🟢 Limpios'),
                    selected: verLimpios,
                    onSelected: (v) => setState(() => verLimpios = v),
                  ),
                  FilterChip(
                    label: const Text('👥 Actividades'),
                    selected: verBrigadas,
                    onSelected: (v) => setState(() => verBrigadas = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (cargando) const Center(child: CircularProgressIndicator()),
        if (seleccionando)
          Positioned(
            top: 90,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Toca en el mapa donde quieres marcar un lugar.',
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'loc',
                onPressed: miUbicacion,
                tooltip: 'Mi ubicación',
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'ref',
                onPressed: recargar,
                tooltip: 'Actualizar mapa',
                child: const Icon(Icons.refresh),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'add',
                tooltip: 'Marcar un lugar',
                onPressed: () async {
                  if (!await asegurarSesion(context)) return;
                  if (!context.mounted) return;
                  setState(() => seleccionando = !seleccionando);
                },
                child: Icon(
                  seleccionando ? Icons.close : Icons.add_location_alt,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selector reutilizable: el administrador toca el mapa para ubicar la actividad.
class ElegirUbicacionPage extends StatefulWidget {
  const ElegirUbicacionPage({super.key});
  @override
  State<ElegirUbicacionPage> createState() => _ElegirUbicacionPageState();
}

class _ElegirUbicacionPageState extends State<ElegirUbicacionPage> {
  LatLng posicion = centroConcepcion;
  final controller = MapController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubicación de la actividad')),
    body: Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: centroConcepcion,
            initialZoom: 13,
            onTap: (_, p) => setState(() => posicion = p),
          ),
          children: [
            mosaicosMapa(),
            MarkerLayer(
              markers: [
                Marker(
                  point: posicion,
                  width: 60,
                  height: 60,
                  child: const Icon(
                    Icons.location_on,
                    size: 54,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            creditosMapa(),
          ],
        ),
        const Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Toca el mapa para seleccionar el lugar de la actividad.',
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, posicion),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar ubicación'),
          ),
        ),
      ],
    ),
  );
}
