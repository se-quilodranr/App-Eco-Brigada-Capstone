import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// PANTALLA: ACTIVIDADES DE MI BRIGADA
// =====================================================

class MisActividadesPage extends StatefulWidget {
  const MisActividadesPage({super.key});

  @override
  State<MisActividadesPage> createState() => _MisActividadesPageState();
}

class _MisActividadesPageState extends State<MisActividadesPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? miBrigada;
  List<Map<String, dynamic>> actividades = [];

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarActividades();
  }

  Future<void> cargarActividades() async {
    if (mounted) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception('Debes iniciar sesión.');
      }

      // Buscar únicamente la brigada creada por mí.
      final brigadas = await supabase
          .from('brigadas')
          .select('id, nombre, comuna, creador_id')
          .eq('creador_id', usuario.id)
          .limit(1);

      Map<String, dynamic>? propia;
      List<Map<String, dynamic>> registros = [];

      if (brigadas.isNotEmpty) {
        propia = Map<String, dynamic>.from(brigadas.first);

        final datos = await supabase
            .from('actividades')
            .select()
            .eq('brigada_id', propia['id'])
            .order('fecha_inicio', ascending: true);

        registros = List<Map<String, dynamic>>.from(datos);
      }

      if (!mounted) return;

      setState(() {
        miBrigada = propia;
        actividades = registros;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  Future<void> abrirFormulario() async {
    if (miBrigada == null) return;

    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadPage(
          brigadaId: miBrigada!['id'].toString(),
          nombreBrigada: miBrigada!['nombre'].toString(),
        ),
      ),
    );

    if (creada == true) {
      await cargarActividades();
    }
  }

  String fechaBonita(String fecha) {
    final f = DateTime.parse(fecha).toLocal();
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    final hora = f.hour.toString().padLeft(2, '0');
    final minuto = f.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${f.year} · $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),
      appBar: AppBar(
        title: const Text('Actividades de mi brigada'),
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actividades de mi brigada',
            icon: const Icon(Icons.event_available_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisActividadesPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: miBrigada == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF176B4D),
              foregroundColor: Colors.white,
              onPressed: abrirFormulario,
              icon: const Icon(Icons.add),
              label: const Text('Nueva actividad'),
            ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : miBrigada == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tienes una brigada creada.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: cargarActividades,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF176B4D),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.eco, color: Colors.white, size: 34),
                          const SizedBox(height: 10),
                          Text(
                            miBrigada!['nombre'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '📍 ${miBrigada!['comuna']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Jornadas programadas',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (actividades.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(
                        child: Text(
                          'Todavía no hay actividades.\n'
                          '¡Organiza la primera jornada!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ...actividades.map(
                    (actividad) => Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_available,
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
                            Text(actividad['descripcion']?.toString() ?? ''),
                            const SizedBox(height: 12),
                            Text(
                              '🕒 ${fechaBonita(actividad['fecha_inicio'].toString())}',
                            ),
                            const SizedBox(height: 6),
                            Text('📍 Ubicación seleccionada en mapa'),
                            const SizedBox(height: 6),
                            Text('Estado: ${actividad['estado']}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}

// =====================================================
// FORMULARIO: CREAR ACTIVIDAD
// =====================================================

class CrearActividadPage extends StatefulWidget {
  final String brigadaId;
  final String nombreBrigada;

  const CrearActividadPage({
    super.key,
    required this.brigadaId,
    required this.nombreBrigada,
  });

  @override
  State<CrearActividadPage> createState() => _CrearActividadPageState();
}

class _CrearActividadPageState extends State<CrearActividadPage> {
  final formulario = GlobalKey<FormState>();
  final titulo = TextEditingController();
  final descripcion = TextEditingController();

  DateTime? fecha;
  TimeOfDay? hora;
  LatLng? ubicacion;

  bool guardando = false;

  @override
  void dispose() {
    titulo.dispose();
    descripcion.dispose();
    super.dispose();
  }

  Future<void> elegirFecha() async {
    final hoy = DateTime.now();

    final seleccion = await showDatePicker(
      context: context,
      initialDate: fecha ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Fecha de la actividad',
    );

    if (seleccion != null && mounted) {
      setState(() => fecha = seleccion);
    }
  }

  Future<void> elegirHora() async {
    final seleccion = await showTimePicker(
      context: context,
      initialTime: hora ?? TimeOfDay.now(),
      helpText: 'Hora de la actividad',
    );

    if (seleccion != null && mounted) {
      setState(() => hora = seleccion);
    }
  }

  Future<void> elegirUbicacion() async {
    final seleccion = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionActividad(puntoInicial: ubicacion),
      ),
    );

    if (seleccion != null && mounted) {
      setState(() => ubicacion = seleccion);
    }
  }

  void mostrarError(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> guardar() async {
    if (!(formulario.currentState?.validate() ?? false)) {
      return;
    }

    if (fecha == null || hora == null) {
      mostrarError('Selecciona la fecha y la hora.');
      return;
    }

    if (ubicacion == null) {
      mostrarError('Selecciona el lugar en el mapa.');
      return;
    }

    final inicio = DateTime(
      fecha!.year,
      fecha!.month,
      fecha!.day,
      hora!.hour,
      hora!.minute,
    );

    if (!inicio.isAfter(DateTime.now())) {
      mostrarError('La fecha y hora deben ser futuras.');
      return;
    }

    if (Supabase.instance.client.auth.currentUser == null) {
      mostrarError('Debes iniciar sesión.');
      return;
    }

    setState(() => guardando = true);

    try {
      await Supabase.instance.client.from('actividades').insert({
        'brigada_id': widget.brigadaId,
        'titulo': titulo.text.trim(),
        'descripcion': descripcion.text.trim(),
        'latitud': ubicacion!.latitude,
        'longitud': ubicacion!.longitude,
        'fecha_inicio': inicio.toUtc().toIso8601String(),
        'estado': 'programada',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Actividad creada correctamente!')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      mostrarError('Error al crear la actividad: $e');
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),
      appBar: AppBar(
        title: const Text('Crear actividad'),
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: formulario,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.eco, size: 44, color: Color(0xFF176B4D)),
                const SizedBox(height: 10),
                Text(
                  'Organizar jornada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(widget.nombreBrigada, textAlign: TextAlign.center),
                const SizedBox(height: 24),

                TextFormField(
                  controller: titulo,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la actividad',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if ((valor ?? '').trim().length < 3) {
                      return 'Escribe un nombre válido.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: descripcion,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: '¿Qué realizarán en la jornada?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if ((valor ?? '').trim().isEmpty) {
                      return 'Escribe una descripción.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                OutlinedButton.icon(
                  onPressed: elegirFecha,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    fecha == null
                        ? 'Seleccionar fecha'
                        : '${fecha!.day}/${fecha!.month}/${fecha!.year}',
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: elegirHora,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    hora == null ? 'Seleccionar hora' : hora!.format(context),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: elegirUbicacion,
                  icon: const Icon(Icons.map),
                  label: Text(
                    ubicacion == null
                        ? 'Elegir ubicación en el mapa'
                        : 'Ubicación seleccionada ✓',
                  ),
                ),

                const SizedBox(height: 25),

                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: const Icon(Icons.check_circle),
                  label: Text(guardando ? 'Guardando...' : 'Crear actividad'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// MAPA: ELEGIR DÓNDE SERÁ LA ACTIVIDAD
// =====================================================

class SeleccionarUbicacionActividad extends StatefulWidget {
  final LatLng? puntoInicial;

  const SeleccionarUbicacionActividad({super.key, this.puntoInicial});

  @override
  State<SeleccionarUbicacionActividad> createState() =>
      _SeleccionarUbicacionActividadState();
}

class _SeleccionarUbicacionActividadState
    extends State<SeleccionarUbicacionActividad> {
  LatLng? punto;

  @override
  void initState() {
    super.initState();
    punto = widget.puntoInicial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de la jornada'),
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: punto ?? const LatLng(-36.827, -73.050),
              initialZoom: 12,
              onTap: (_, posicion) {
                setState(() {
                  punto = posicion;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (punto != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: punto!,
                      width: 55,
                      height: 55,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: 15,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  punto == null
                      ? 'Toca el mapa para elegir el lugar.'
                      : 'Ubicación marcada correctamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: punto == null
                ? null
                : () => Navigator.pop(context, punto),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar ubicación'),
          ),
        ),
      ),
    );
  }
}
