import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/design.dart';
import '../core/eco_analisis.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../widgets/common.dart';

class EcoMapa extends StatefulWidget {
  final EcoStore store;
  final void Function(LatLng) crearEn;
  final void Function(String) verReporte;
  final void Function(String)? verBrigada;
  const EcoMapa({super.key, required this.store,
    required this.crearEn, required this.verReporte, this.verBrigada});
  @override
  State<EcoMapa> createState() => _EcoMapaState();
}

class _EcoMapaState extends State<EcoMapa> {
  final MapController controller = MapController();
  String filtro = 'Todos';
  LatLng? usuario;
  double radio = 15;
  bool verZonas = true;
  bool verBrigadas = true;
  bool verReciclaje = true;
  bool verLugaresComunitarios = true;

  Color _colorPorEstado(String estado) => switch (estado) {
    'pendiente' => const Color(0xFFC94843),
    'validado' => const Color(0xFFE09C34),
    'asignado' => const Color(0xFFD57B26),
    'en_proceso' => const Color(0xFF2674C9),
    'en_revision' => const Color(0xFF8A50BA),
    'cerrado' => EcoColors.green,
    'descartado' => Colors.grey,
    _ => EcoColors.orange,
  };

  Widget _leyenda(String texto, Color color) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(texto, style: const TextStyle(fontSize: 10,
        color: EcoColors.muted)),
    ]);

  void _mostrarBrigada(Brigada b) => showDialog<void>(context: context,
    builder: (ctx) => AlertDialog(
      title: Text(b.nombre),
      content: Text('${b.descripcion}\n\nComuna: ${b.comuna}\n'
        'Integrantes estimados: ${b.miembros}\n'
        'Estado: ${b.disponible ? 'Disponible' : 'Pausada'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar')),
        if (widget.verBrigada != null)
          FilledButton.icon(onPressed: () {
            Navigator.pop(ctx);
            widget.verBrigada!(b.id);
          }, icon: const Icon(Icons.forum_outlined),
            label: const Text('Brigada y chat')),
      ]));

  void _mostrarReciclaje(PuntoReciclaje punto) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(punto.nombre),
      content: Text('${punto.descripcion}\n\nComuna: ${punto.comuna}\n'
        'Punto registrado en EcoBrigada. Verifica las condiciones de atención antes de dirigirte.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
        child: const Text('Entendido'))]));

  void _mostrarLugarOriginal(Map<String,dynamic> lugar) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${lugar['nombre'] ?? 'Lugar comunitario'}'),
      content: Text('${lugar['descripcion'] ?? ''}\n\n'
        'Estado actual: ${lugar['estado']=='limpio'?'Limpio':'Con residuos'}\n'
        'Este punto procede del registro existente en tu Supabase.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),child: const Text('Cerrar')),
        FilledButton(onPressed: () async {
          final nuevo = lugar['estado']=='limpio'?'sucio':'limpio';
          Navigator.pop(ctx);
          try { await widget.store.marcarLugarOriginal('${lugar['id']}',nuevo); }
          catch (e) {if (mounted) mostrarError(context,e);}
        },child: Text(lugar['estado']=='limpio'?'Marcar con residuos':'Marcar limpio')),
      ],
    ),
  );

  Future<void> localizar() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Activa la ubicación del dispositivo.');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        throw StateError('Se requiere permiso para usar la ubicación.');
      }
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => usuario = LatLng(p.latitude, p.longitude));
      controller.move(usuario!, 14.5);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportes = widget.store.reportes.where((r) {
      if (filtro == 'Activos' && !r.abierto) return false;
      if (filtro == 'Por resolver' && !['pendiente','validado','asignado'].contains(r.estado)) return false;
      if (filtro == 'En ejecución' && r.estado != 'en_proceso') return false;
      if (filtro == 'En revisión' && r.estado != 'en_revision') return false;
      if (filtro == 'Resueltos' && r.estado != 'cerrado') return false;
      if (filtro == 'Descartados' && r.estado != 'descartado') return false;
      if (usuario != null && const Distance().as(LengthUnit.Kilometer,
          usuario!, r.punto) > radio) return false;
      return true;
    }).toList();
    final zonas = detectarEcoZonas(reportes);
    final equipoVisibles = widget.store.brigadas.where((b) =>
      !widget.store.brigadasSinCoordenadas.contains(b.id) && (usuario == null || const Distance().as(LengthUnit.Kilometer,
        usuario!, b.punto) <= radio)).toList();
    final puntosReciclaje = widget.store.puntosReciclaje.where((p) =>
      usuario == null || const Distance().as(LengthUnit.Kilometer,
        usuario!, p.punto) <= radio).toList();
    final lugaresOriginales = widget.store.lugaresOriginales.where((l) {
      final lat = (l['latitud'] as num?)?.toDouble();
      final lng = (l['longitud'] as num?)?.toDouble();
      if(lat==null || lng==null || lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
      return usuario==null || const Distance().as(LengthUnit.Kilometer,
        usuario!,LatLng(lat,lng))<=radio;
    }).toList();
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Padding(padding: EdgeInsets.fromLTRB(compact ? 12 : 26, 12,
      compact ? 12 : 26, 16), child: Column(children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EcoMapa', style: TextStyle(fontSize: 25,
              fontWeight: FontWeight.w900, color: EcoColors.forest)),
            Text('Explora, ubica y reporta problemas ambientales',
              style: TextStyle(color: EcoColors.muted, fontSize: 12)),
          ])),
        FilledButton.icon(onPressed: () => widget.crearEn(usuario ?? ecoCentro),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(compact ? 'Nuevo' : 'Nuevo reporte')),
      ]),
      const SizedBox(height: 15),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          FlutterMap(mapController: controller,
            options: const MapOptions(initialCenter: ecoCentro,
              initialZoom: 11.1, minZoom: 4, maxZoom: 19),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'cl.ecobrigada.capstone'),
              // EcoZonas: círculos calculados localmente a partir de incidencias.
              if (verZonas)
                CircleLayer(circles: [
                  for (final zona in zonas)
                    CircleMarker(
                      point: zona.centro,
                      radius: zona.radioMetros,
                      useRadiusInMeter: true,
                      color: const Color(0xFFDE752B).withValues(alpha: 0.17),
                      borderColor: const Color(0xFFCB672B),
                      borderStrokeWidth: 2,
                    ),
                ]),
              MarkerLayer(markers: [
                if (verZonas)
                  for (final zona in zonas)
                    Marker(point: zona.centro, width: 46, height: 46,
                      child: Tooltip(
                        message: 'EcoZona · ${zona.reportesActivos} reportes · '
                          'prioridad ${zona.nivel}',
                        child: InkWell(
                          onTap: () => showDialog<void>(context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Zona de concentración'),
                              content: Text('${zona.reportesActivos} incidencias '
                                'abiertas cercanas en ${zona.comuna}. '
                                'Índice orientativo ${zona.indice}/100. '
                                'Radio aproximado ${zona.radioMetros.round()} m. '
                                'No implica contaminación confirmada en todo el círculo.'),
                              actions: [TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cerrar'))],
                            )),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFCB672B),
                              border: Border.all(color: Colors.white, width: 2),
                              shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${zona.reportesActivos}',
                              style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                for (final r in reportes)
                  Marker(point: r.punto, width: 44, height: 50,
                    child: Tooltip(message: '${estadoNombre(r.estado)} · ${r.titulo}',
                      child: InkWell(onTap: () => widget.verReporte(r.id),
                        child: Icon(Icons.location_on_rounded,
                          color: _colorPorEstado(r.estado), size: 43,
                          shadows: const [Shadow(color: Colors.white,
                            blurRadius: 6)])))),
                if (verBrigadas)
                  for (final b in equipoVisibles)
                    Marker(point: b.punto, width: 40, height: 40,
                      child: Tooltip(message: 'Brigada: ${b.nombre}',
                        child: InkWell(onTap: () => _mostrarBrigada(b),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.groups_rounded,
                              color: Colors.white, size: 23))))),
                if (verLugaresComunitarios)
                  for (final l in lugaresOriginales)
                    Marker(point: LatLng((l['latitud'] as num).toDouble(),
                        (l['longitud'] as num).toDouble()), width: 40, height: 42,
                      child: Tooltip(message: '${l['nombre']} · ${l['estado']}',
                        child: InkWell(onTap: () => _mostrarLugarOriginal(l),
                          child: Container(
                            decoration: BoxDecoration(
                              color: l['estado']=='limpio' ? EcoColors.green :
                                const Color(0xFFC94843),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white,width: 2)),
                            child: Icon(l['estado']=='limpio' ? Icons.verified_outlined :
                                Icons.delete_outline_rounded,
                              size: 23,color: Colors.white))))),
                if (verReciclaje)
                  for (final p in puntosReciclaje)
                    Marker(point: p.punto, width: 39, height: 39,
                      child: Tooltip(message: p.nombre,
                        child: InkWell(onTap: () => _mostrarReciclaje(p),
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFF16856B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.recycling_rounded,
                              color: Colors.white, size: 23))))),
                if (usuario != null)
                  Marker(point: usuario!, width: 38, height: 38,
                    child: const Icon(Icons.my_location_rounded,
                      color: Color(0xFF3676CE), size: 33)),
              ]),
              RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors',
                  onTap: () {}),
              ]),
            ],
          ),
          Positioned(left: 12, top: 12, right: 12,
            child: Card(elevation: 2, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Expanded(child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(isExpanded: true, value: filtro,
                    items: ['Todos', 'Activos', 'Por resolver', 'En ejecución', 'En revisión', 'Resueltos', 'Descartados'].map((f) =>
                      DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setState(() => filtro = v ?? 'Todos'),
                  ))),
                IconButton(
                  tooltip: verZonas ? 'Ocultar zonas críticas' : 'Ver zonas críticas',
                  onPressed: () => setState(() => verZonas = !verZonas),
                  icon: Icon(Icons.layers_rounded,
                    color: verZonas ? const Color(0xFFCB672B) : EcoColors.muted),
                ),
                IconButton(
                  tooltip: verBrigadas ? 'Ocultar brigadas' : 'Ver brigadas',
                  onPressed: () => setState(() => verBrigadas = !verBrigadas),
                  icon: Icon(Icons.groups_outlined,
                    color: verBrigadas ? Colors.blue.shade700 : EcoColors.muted)),
                IconButton(
                  tooltip: verLugaresComunitarios ? 'Ocultar lugares comunitarios' : 'Ver lugares comunitarios',
                  onPressed: () => setState(() => verLugaresComunitarios = !verLugaresComunitarios),
                  icon: Icon(Icons.place_outlined,
                    color: verLugaresComunitarios ? EcoColors.green : EcoColors.muted)),
                IconButton(
                  tooltip: verReciclaje ? 'Ocultar puntos de reciclaje' : 'Ver puntos de reciclaje',
                  onPressed: () => setState(() => verReciclaje = !verReciclaje),
                  icon: Icon(Icons.recycling_rounded,
                    color: verReciclaje ? const Color(0xFF16856B) : EcoColors.muted)),
                if (!compact) Text('${reportes.length} incidencias',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            )),
          ),
          Positioned(right: 14, bottom: 56, child: Column(children: [
            FloatingActionButton.small(heroTag: 'gps', onPressed: localizar,
              tooltip: 'Mi ubicación', backgroundColor: Colors.white,
              child: const Icon(Icons.my_location_rounded, color: EcoColors.forest)),
            const SizedBox(height: 8),
            FloatingActionButton.small(heroTag: 'zoom',
              onPressed: () => controller.move(controller.camera.center,
                (controller.camera.zoom + 1).clamp(4, 19).toDouble()),
              backgroundColor: Colors.white,
              child: const Icon(Icons.add, color: EcoColors.forest)),
          ])),
        ]))),
      const SizedBox(height: 11),
      Row(children: [
        const Icon(Icons.radar, size: 17, color: EcoColors.green),
        const SizedBox(width: 5),
        const Text('Radio GPS', style: TextStyle(fontWeight: FontWeight.w700,
          fontSize: 12)),
        Expanded(child: Slider(min: 1, max: 30, divisions: 29, value: radio,
          onChanged: (v) => setState(() => radio = v))),
        SizedBox(width: 43, child: Text('${radio.round()} km',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
      ]),
      Wrap(spacing: 10, runSpacing: 4, alignment: WrapAlignment.center,
        children: [
          _leyenda('Pendiente', const Color(0xFFC94843)),
          _leyenda('En ejecución', const Color(0xFF2674C9)),
          _leyenda('En revisión', const Color(0xFF8A50BA)),
          _leyenda('Cerrado', EcoColors.green),
          _leyenda('Brigadas', Colors.blue.shade700),
          _leyenda('Reciclaje', const Color(0xFF16856B)),
          _leyenda('Lugares comunitarios', const Color(0xFFC94843)),
        ]),
      const SizedBox(height: 4),
      const Text('Los marcadores provienen de los registros Supabase. '
        'El filtro por radio se aplica al activar GPS. Los puntos de reciclaje '
        'solo aparecen si fueron verificados. Los lugares comunitarios '
        'conservan sus estados originales.',
        textAlign: TextAlign.center,
        style: TextStyle(color: EcoColors.muted, fontSize: 10)),
    ]));
  }
}

/// Selector geográfico: toca el mapa para fijar coordenadas al crear un reporte.
class SelectorPunto extends StatefulWidget {
  final LatLng inicial;
  final ValueChanged<LatLng> onChanged;
  const SelectorPunto({super.key, required this.inicial, required this.onChanged});
  @override
  State<SelectorPunto> createState() => _SelectorPuntoState();
}

class _SelectorPuntoState extends State<SelectorPunto> {
  late LatLng seleccionado = widget.inicial;
  @override
  Widget build(BuildContext context) => Column(children: [
    const Align(alignment: Alignment.centerLeft,
      child: Text('Ubicación: toca el mapa para colocar el marcador',
        style: TextStyle(fontWeight: FontWeight.w700))),
    const SizedBox(height: 10),
    SizedBox(height: 220, child: ClipRRect(borderRadius: BorderRadius.circular(16),
      child: FlutterMap(options: MapOptions(initialCenter: seleccionado,
        initialZoom: 13, onTap: (_, p) {
          setState(() => seleccionado = p);
          widget.onChanged(p);
        }), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cl.ecobrigada.capstone'),
          MarkerLayer(markers: [Marker(point: seleccionado,
            width: 45, height: 45,
            child: const Icon(Icons.location_pin, color: EcoColors.green, size: 45))]),
          RichAttributionWidget(attributions: [
            TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
          ]),
        ]))),
    const SizedBox(height: 5),
    Text('${seleccionado.latitude.toStringAsFixed(5)}, ${seleccionado.longitude.toStringAsFixed(5)}',
      style: const TextStyle(color: EcoColors.muted, fontSize: 11)),
  ]);
}
