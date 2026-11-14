import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/api.dart';
import 'chat_page.dart';
import 'mapa_page.dart';

class BrigadasPage extends StatefulWidget {
  const BrigadasPage({super.key});
  @override
  State<BrigadasPage> createState() => _BrigadasPageState();
}

class _BrigadasPageState extends State<BrigadasPage> {
  late Future<List<Map<String, dynamic>>> future;
  String filtro = '';
  @override
  void initState() {
    super.initState();
    refrescar();
  }

  void refrescar() => setState(() => future = Api.brigadas());

  Future<void> nuevaBrigada() async {
    if (!await asegurarSesion(context)) return;
    if (!mounted) return;
    final nombre = TextEditingController();
    final comuna = TextEditingController();
    final descripcion = TextEditingController();
    String estado = 'abierta';
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, cambiar) => AlertDialog(
          title: const Text('Crear brigada'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombre,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la brigada',
                    ),
                  ),
                  TextField(
                    controller: comuna,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Comuna'),
                  ),
                  TextField(
                    controller: descripcion,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: estado,
                    decoration: const InputDecoration(
                      labelText: 'Solicitudes de ingreso',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'abierta',
                        child: Text('Abierta: recibe solicitudes'),
                      ),
                      DropdownMenuItem(
                        value: 'cerrada',
                        child: Text('Cerrada: no recibe solicitudes'),
                      ),
                    ],
                    onChanged: (v) => cambiar(() => estado = v ?? 'abierta'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'nombre': nombre.text,
                'comuna': comuna.text,
                'descripcion': descripcion.text,
                'estado': estado,
              }),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    nombre.dispose();
    comuna.dispose();
    descripcion.dispose();
    if (!mounted || datos == null) return;
    if ((datos['nombre'] ?? '').trim().length < 3 ||
        (datos['comuna'] ?? '').trim().length < 2) {
      mostrarError(context, 'Completa el nombre y la comuna');
      return;
    }
    try {
      final id = await Api.crearBrigada(
        nombre: datos['nombre']!,
        comuna: datos['comuna']!,
        descripcion: datos['descripcion']!,
        estado: datos['estado']!,
      );
      refrescar();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BrigadaDetallePage(brigadaId: id)),
      );
      refrescar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Brigadas comunitarias',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: nuevaBrigada,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => filtro = v.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o comuna',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final lista = (snap.data ?? [])
                .where(
                  (b) => '${b['nombre']} ${b['comuna']}'.toLowerCase().contains(
                    filtro,
                  ),
                )
                .toList();
            if (lista.isEmpty) {
              return const Center(child: Text('No hay brigadas creadas.'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                refrescar();
                await future;
              },
              child: LayoutBuilder(
                builder: (ctx, c) => GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.maxWidth > 960
                        ? 3
                        : c.maxWidth > 550
                        ? 2
                        : 1,
                    mainAxisExtent: 205,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final b = lista[i];
                    final abierto = b['estado'] == 'abierta';
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BrigadaDetallePage(
                                brigadaId: b['id'].toString(),
                              ),
                            ),
                          );
                          refrescar();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.groups,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 34,
                                  ),
                                  const Spacer(),
                                  Chip(
                                    label: Text(
                                      abierto ? '🟢 Abierta' : '🔒 Cerrada',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                b['nombre'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('📍 ${b['comuna']}', maxLines: 1),
                              const SizedBox(height: 6),
                              Text(
                                b['descripcion']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text('Ver brigada →'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class BrigadaDetallePage extends StatefulWidget {
  final String brigadaId;
  const BrigadaDetallePage({super.key, required this.brigadaId});
  @override
  State<BrigadaDetallePage> createState() => _BrigadaDetallePageState();
}

class _BrigadaDetallePageState extends State<BrigadaDetallePage> {
  Map<String, dynamic>? brigada;
  List<Map<String, dynamic>> actividades = [];
  List<Map<String, dynamic>> miembros = [];
  List<Map<String, dynamic>> solicitudes = [];
  bool loading = true;
  bool soyMiembro = false;
  bool get admin => Api.db.auth.currentUser?.id == brigada?['creador_id'];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final b = await Api.db
          .from('brigadas')
          .select()
          .eq('id', widget.brigadaId)
          .single();
      final a = await Api.actividades(brigadaId: widget.brigadaId);
      final m = await Api.miembros(widget.brigadaId);
      final actual = Api.db.auth.currentUser?.id;
      final esAdmin = actual != null && b['creador_id'] == actual;
      final s = esAdmin
          ? await Api.solicitudesBrigada(widget.brigadaId)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        brigada = b;
        actividades = a;
        miembros = m;
        solicitudes = s;
        soyMiembro = actual != null && m.any((x) => x['usuario_id'] == actual);
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        mostrarError(context, e);
      }
    }
  }

  Future<void> cambiarEstado() async {
    final nuevo = brigada?['estado'] == 'abierta' ? 'cerrada' : 'abierta';
    try {
      await Api.cambiarEstadoBrigada(widget.brigadaId, nuevo);
      await cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> solicitar({String? actividadId}) async {
    if (!await asegurarSesion(context)) return;
    try {
      await Api.solicitar(
        brigadaId: widget.brigadaId,
        actividadId: actividadId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Debes esperar la aprobación del administrador.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> crearActividad() async {
    final titulo = TextEditingController();
    final descripcion = TextEditingController();
    LatLng? ubicacion;
    DateTime fecha = DateTime.now().add(const Duration(days: 1));
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (ctx, cambiar) => AlertDialog(
          title: const Text('Organizar actividad'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titulo,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la actividad',
                    ),
                  ),
                  TextField(
                    controller: descripcion,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '¿Qué harán?'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final p = await Navigator.push<LatLng>(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => const ElegirUbicacionPage(),
                        ),
                      );
                      if (ctx.mounted && p != null) {
                        cambiar(() => ubicacion = p);
                      }
                    },
                    icon: const Icon(Icons.place),
                    label: Text(
                      ubicacion == null
                          ? 'Seleccionar lugar en mapa'
                          : 'Ubicación elegida ✓',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final dia = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (dia == null || !ctx.mounted) return;
                      final hora = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(fecha),
                      );
                      if (!ctx.mounted || hora == null) return;
                      cambiar(
                        () => fecha = DateTime(
                          dia.year,
                          dia.month,
                          dia.day,
                          hora.hour,
                          hora.minute,
                        ),
                      );
                    },
                    icon: const Icon(Icons.event),
                    label: Text(
                      'Inicio: ${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'titulo': titulo.text,
                'descripcion': descripcion.text,
                'ubicacion': ubicacion,
                'fecha': fecha,
              }),
              child: const Text('Crear actividad'),
            ),
          ],
        ),
      ),
    );
    titulo.dispose();
    descripcion.dispose();
    if (!mounted || datos == null) return;
    if ((datos['titulo'] as String).trim().length < 3 ||
        datos['ubicacion'] == null) {
      mostrarError(
        context,
        'Escribe un título y selecciona el lugar en el mapa',
      );
      return;
    }
    final p = datos['ubicacion'] as LatLng;
    try {
      await Api.crearActividad(
        brigadaId: widget.brigadaId,
        titulo: datos['titulo'] as String,
        descripcion: datos['descripcion'] as String,
        lat: p.latitude,
        lon: p.longitude,
        inicio: datos['fecha'] as DateTime,
      );
      await cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> resolver(String solicitudId, bool aprobar) async {
    try {
      await Api.resolver(solicitudId, aprobar);
      await cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final b = brigada;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No se encontró la brigada')),
      );
    }

    final abierta = b['estado'] == 'abierta';
    final pendientes = solicitudes
        .where((s) => s['estado'] == 'pendiente')
        .toList();
    final contenido = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b['nombre'].toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text('📍 ${b['comuna']}'),
              Text(b['descripcion']?.toString() ?? ''),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  abierta
                      ? '🟢 Abierta a solicitudes'
                      : '🔒 Cerrada a solicitudes',
                ),
              ),
              Text('Miembros: ${miembros.length}'),
              const SizedBox(height: 12),
              if (admin) ...[
                SwitchListTile(
                  title: const Text('Recibir solicitudes'),
                  subtitle: Text(
                    abierta ? 'Brigada abierta' : 'Brigada cerrada',
                  ),
                  value: abierta,
                  onChanged: (_) => cambiarEstado(),
                ),
                FilledButton.icon(
                  onPressed: crearActividad,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Nueva actividad'),
                ),
              ] else if (!soyMiembro && abierta) ...[
                FilledButton.icon(
                  onPressed: () => solicitar(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Solicitar unirme a la brigada'),
                ),
              ] else if (!soyMiembro) ...[
                const Text('Esta brigada está cerrada. No recibe solicitudes.'),
              ],
              if (soyMiembro)
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        brigadaId: widget.brigadaId,
                        nombreBrigada: b['nombre'].toString(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Ingresar al chat'),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text('Actividades', style: Theme.of(context).textTheme.titleLarge),
    ];

    if (actividades.isEmpty) {
      contenido.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Esta brigada no tiene actividades todavía.'),
        ),
      );
    }

    for (final a in actividades) {
      final inicio = a['fecha_inicio']?.toString().replaceFirst('T', ' ') ?? '';
      final fecha = inicio.length >= 16 ? inicio.substring(0, 16) : inicio;
      contenido.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['titulo'].toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(a['descripcion']?.toString() ?? ''),
                Text('Estado: ${a['estado']}'),
                Text('Fecha: $fecha'),
                if (admin)
                  DropdownButton<String>(
                    value: a['estado'] as String,
                    items: const [
                      DropdownMenuItem(
                        value: 'programada',
                        child: Text('Programada'),
                      ),
                      DropdownMenuItem(
                        value: 'en_curso',
                        child: Text('En curso'),
                      ),
                      DropdownMenuItem(
                        value: 'finalizada',
                        child: Text('Finalizada'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      try {
                        await Api.cambiarEstadoActividad(
                          a['id'].toString(),
                          value,
                        );
                        await cargar();
                      } catch (e) {
                        if (context.mounted) {
                          mostrarError(context, e);
                        }
                      }
                    },
                  ),
                if (!admin && abierta && a['estado'] != 'finalizada')
                  TextButton.icon(
                    onPressed: () => solicitar(actividadId: a['id'].toString()),
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Solicitar participar'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (admin) {
      contenido.addAll([
        const SizedBox(height: 14),
        Text(
          'Solicitudes recibidas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ]);
      if (pendientes.isEmpty) {
        contenido.add(
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No hay solicitudes pendientes.'),
          ),
        );
      }
      for (final s in pendientes) {
        contenido.add(
          Card(
            child: ListTile(
              title: Text(
                (s['perfiles'] as Map?)?['nombre']?.toString() ?? 'Usuario',
              ),
              subtitle: Text(
                s['actividad_id'] == null
                    ? 'Solicita ingresar a la brigada'
                    : 'Actividad: ${(s['actividades'] as Map?)?['titulo'] ?? 'Actividad'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Aceptar',
                    onPressed: () => resolver(s['id'].toString(), true),
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  IconButton(
                    tooltip: 'Rechazar',
                    onPressed: () => resolver(s['id'].toString(), false),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    contenido.addAll([
      const SizedBox(height: 14),
      Text('Integrantes', style: Theme.of(context).textTheme.titleLarge),
    ]);
    for (final m in miembros) {
      contenido.add(
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            (m['perfiles'] as Map?)?['nombre']?.toString() ?? 'Usuario',
          ),
          subtitle: Text(m['rol'].toString()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(b['nombre'].toString()),
        actions: [
          IconButton(onPressed: cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargar,
        child: ListView(padding: const EdgeInsets.all(16), children: contenido),
      ),
    );
  }
}
