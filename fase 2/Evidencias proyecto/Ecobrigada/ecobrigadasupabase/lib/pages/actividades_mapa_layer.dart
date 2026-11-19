
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActividadesMapaLayer extends StatefulWidget {
  const ActividadesMapaLayer({super.key});

  @override
  State<ActividadesMapaLayer> createState() =>
      _ActividadesMapaLayerState();
}

class _ActividadesMapaLayerState
    extends State<ActividadesMapaLayer> {
  late final Stream<List<Map<String, dynamic>>> actividadesStream;

  @override
  void initState() {
    super.initState();

    // Escuchar cambios automáticamente desde Supabase.
    actividadesStream = Supabase.instance.client
        .from('actividades')
        .stream(primaryKey: ['id']);
  }

  void mostrarActividad(Map<String, dynamic> actividad) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_available_rounded,
                color: Colors.deepOrange,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                actividad['titulo']?.toString() ?? 'Actividad',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                actividad['descripcion']?.toString() ?? '',
              ),
              const SizedBox(height: 12),
              Text(
                'Estado: ${actividad['estado'] ?? 'programada'}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Actividad comunitaria de EcoBrigada',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: actividadesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            'Error al cargar actividades: ${snapshot.error}',
          );
        }

        final actividades = snapshot.data ?? [];
        final marcadores = <Marker>[];

        for (final actividad in actividades) {
          final lat =
              (actividad['latitud'] as num?)?.toDouble();
          final lng =
              (actividad['longitud'] as num?)?.toDouble();

          if (lat == null || lng == null) {
            continue;
          }

          marcadores.add(
            Marker(
              point: LatLng(lat, lng),
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: () => mostrarActividad(actividad),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          );
        }

        return MarkerLayer(markers: marcadores);
      },
    );
  }
}
