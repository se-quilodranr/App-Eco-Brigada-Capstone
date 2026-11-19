
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActividadesBrigadaSection extends StatefulWidget {
  final String brigadaId;

  const ActividadesBrigadaSection({
    super.key,
    required this.brigadaId,
  });

  @override
  State<ActividadesBrigadaSection> createState() =>
      _ActividadesBrigadaSectionState();
}

class _ActividadesBrigadaSectionState
    extends State<ActividadesBrigadaSection> {
  late Stream<List<Map<String, dynamic>>> actividadesStream;

  @override
  void initState() {
    super.initState();
    configurarStream();
  }

  @override
  void didUpdateWidget(covariant ActividadesBrigadaSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.brigadaId != widget.brigadaId) {
      configurarStream();
    }
  }

  void configurarStream() {
    actividadesStream = Supabase.instance.client
        .from('actividades')
        .stream(primaryKey: ['id'])
        .eq('brigada_id', widget.brigadaId)
        .order('fecha_inicio', ascending: true);
  }

  String formatearFecha(dynamic valor) {
    final fecha = DateTime.parse(valor.toString()).toLocal();

    String dos(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}'
        ' · ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  void abrirMapa(Map<String, dynamic> actividad) {
    final lat = (actividad['latitud'] as num?)?.toDouble();
    final lng = (actividad['longitud'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta actividad no tiene ubicación.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapaActividadPage(
          nombre: actividad['titulo'].toString(),
          ubicacion: LatLng(lat, lng),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),

        const Text(
          '📅 Actividades de esta brigada',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF176B4D),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Jornadas ambientales organizadas por el equipo.',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: actividadesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Error al cargar actividades: ${snapshot.error}',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final actividades = snapshot.data!;

            if (actividades.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(
                    child: Text(
                      'Todavía no hay actividades programadas.',
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: actividades.map((actividad) {
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              color: Color(0xFF176B4D),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                actividad['titulo'].toString(),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          actividad['descripcion']
                                  ?.toString() ??
                              '',
                        ),

                        const SizedBox(height: 12),

                        Text(
                          '🕒 ${formatearFecha(
                            actividad['fecha_inicio'],
                          )}',
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Estado: ${actividad['estado']}',
                          style: const TextStyle(
                            color: Color(0xFF176B4D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => abrirMapa(actividad),
                            icon: const Icon(
                              Icons.location_on_outlined,
                            ),
                            label: const Text('Ver ubicación'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// PANTALLA PARA VER LA ACTIVIDAD EN EL MAPA

class MapaActividadPage extends StatelessWidget {
  final String nombre;
  final LatLng ubicacion;

  const MapaActividadPage({
    super.key,
    required this.nombre,
    required this.ubicacion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
        title: Text(nombre),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: ubicacion,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cl.ecobrigada.app',
          ),

          MarkerLayer(
            markers: [
              Marker(
                point: ubicacion,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.deepOrange,
                  size: 52,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
