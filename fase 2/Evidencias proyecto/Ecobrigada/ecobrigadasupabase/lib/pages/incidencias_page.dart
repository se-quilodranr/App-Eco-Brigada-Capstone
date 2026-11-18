import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/algorithms.dart';
import '../core/design.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import 'mapa_page.dart';

class EcoIncidencias extends StatefulWidget {
  final EcoStore store;
  final VoidCallback nuevoReporte;
  final void Function(String) verReporte;
  const EcoIncidencias({
    super.key,
    required this.store,
    required this.nuevoReporte,
    required this.verReporte,
  });
  @override
  State<EcoIncidencias> createState() => _EcoIncidenciasState();
}

class _EcoIncidenciasState extends State<EcoIncidencias> {
  String filtro = 'Todos';
  String texto = '';
  @override
  Widget build(BuildContext context) {
    final reportes = widget.store.recientes.where((r) {
      if (filtro != 'Todos' && r.estado != filtro) return false;
      final q = texto.toLowerCase();
      return r.titulo.toLowerCase().contains(q) ||
          r.comuna.toLowerCase().contains(q) ||
          r.tipo.toLowerCase().contains(q);
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 35),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de incidencias',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: EcoColors.forest,
                    ),
                  ),
                  Text(
                    'Del reporte a una solución verificable',
                    style: TextStyle(color: EcoColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: widget.nuevoReporte,
              icon: const Icon(Icons.add),
              label: const Text('Crear'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        EcoPanel(
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => texto = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por título, tipo o comuna...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: filtro,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: ['Todos', ...estadosReporte]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e == 'Todos' ? e : estadoNombre(e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => filtro = v ?? 'Todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${reportes.length} reportes encontrados',
          style: const TextStyle(
            color: EcoColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (reportes.isEmpty)
          const EmptyEco(
            titulo: 'No hay incidencias',
            descripcion: 'Cambia el filtro o registra el primer reporte.',
          ),
        for (final r in reportes) ...[
          ReporteTile(reporte: r, onTap: () => widget.verReporte(r.id)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class NuevoReportePage extends StatefulWidget {
  final EcoStore store;
  final LatLng? initialPunto;
  const NuevoReportePage({super.key, required this.store, this.initialPunto});
  @override
  State<NuevoReportePage> createState() => _NuevoReportePageState();
}

class _NuevoReportePageState extends State<NuevoReportePage> {
  final form = GlobalKey<FormState>();
  final titulo = TextEditingController();
  final descripcion = TextEditingController();
  final direccion = TextEditingController();
  final comuna = TextEditingController(text: 'Concepción');
  String tipo = 'Basura';
  int gravedad = 3;
  late LatLng posicion = widget.initialPunto ?? ecoCentro;
  bool guardando = false;
  XFile? fotoInicial;

  @override
  void dispose() {
    titulo.dispose();
    descripcion.dispose();
    direccion.dispose();
    comuna.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    setState(() => guardando = true);
    try {
      final matches = buscarDuplicados(
        posicion: posicion,
        tipo: tipo,
        reportes: widget.store.reportes,
      );
      if (matches.isNotEmpty) {
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('EcoRadar: posible duplicado'),
            content: Text(
              'Se encontraron ${matches.length} reportes similares a menos de 150 m. ¿Deseas crear uno nuevo de todas formas?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Revisaré primero'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crear igualmente'),
              ),
            ],
          ),
        );
        if (seguir != true) return;
      }
      final resultado = await widget.store.crearReporte(
        titulo: titulo.text,
        descripcion: descripcion.text,
        tipo: tipo,
        direccion: direccion.text,
        comuna: comuna.text,
        punto: posicion,
        gravedad: gravedad,
        fotoInicial: fotoInicial,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado == 'pendiente-local'
                ? 'Sin conexión: reporte guardado para sincronizar.'
                : 'Reporte registrado correctamente.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  String? _obligatorio(String? s) => s == null || s.trim().length < 3
      ? 'Ingresa al menos tres caracteres.'
      : null;

  @override
  Widget build(BuildContext context) {
    final matches = buscarDuplicados(
      posicion: posicion,
      tipo: tipo,
      reportes: widget.store.reportes,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo reporte ambiental')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const EcoSection(
                  title: 'Cuéntanos qué sucede',
                  subtitle:
                      'Completa los detalles para que la comunidad pueda actuar',
                ),
                TextFormField(
                  controller: titulo,
                  validator: (v) => v == null || v.trim().length < 5
                      ? 'Escribe un título de al menos 5 caracteres.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Título del problema',
                  ),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: descripcion,
                  minLines: 3,
                  maxLines: 5,
                  validator: (v) => v == null || v.trim().length < 10
                      ? 'Describe el problema con al menos 10 caracteres.'
                      : null,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de residuo',
                  ),
                  items: tiposReporte
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => tipo = v ?? tipo),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: comuna,
                        validator: _obligatorio,
                        decoration: const InputDecoration(labelText: 'Comuna'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: direccion,
                        validator: _obligatorio,
                        decoration: const InputDecoration(
                          labelText: 'Sector o dirección',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                EcoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gravedad declarada: $gravedad/5',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Slider(
                        min: 1,
                        max: 5,
                        divisions: 4,
                        value: gravedad.toDouble(),
                        label: '$gravedad',
                        onChanged: (v) => setState(() => gravedad = v.round()),
                      ),
                      Text(
                        'Prioridad preliminar: ${calcularPrioridad(gravedad: gravedad, diasAbierto: 0, reportesCercanos: matches.length)} / 100',
                        style: const TextStyle(color: EcoColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SelectorPunto(
                  inicial: posicion,
                  onChanged: (p) => setState(() => posicion = p),
                ),
                const SizedBox(height: 15),
                if (matches.isNotEmpty)
                  EcoPanel(
                    child: Row(
                      children: [
                        const Icon(Icons.radar, color: EcoColors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'EcoRadar detectó ${matches.length} reporte(s) similares y cercanos. Revisa antes de publicar.',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                EcoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evidencia inicial (fotografía)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fotoInicial == null
                            ? 'Sin fotografía seleccionada.'
                            : fotoInicial!.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (file != null && mounted) {
                            setState(() => fotoInicial = file);
                          }
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Adjuntar fotografía'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(guardando ? 'Guardando...' : 'Enviar reporte'),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetalleReportePage extends StatefulWidget {
  final EcoStore store;
  final String id;
  const DetalleReportePage({super.key, required this.store, required this.id});
  @override
  State<DetalleReportePage> createState() => _DetalleReportePageState();
}

class _DetalleReportePageState extends State<DetalleReportePage> {
  bool consultandoHistorial = false;
  @override
  void initState() {
    super.initState();
    _refrescarHistorial();
  }

  Future<void> _refrescarHistorial() async {
    setState(() => consultandoHistorial = true);
    try {
      await Future.wait([
        widget.store.cargarHistorial(widget.id),
        widget.store.cargarEvidencias(widget.id),
      ]);
    } catch (_) {
      /* El detalle sigue disponible si la auditoría falla. */
    }
    if (mounted) setState(() => consultandoHistorial = false);
  }

  Future<void> ejecutar(Reporte r, String siguiente) async {
    String equipo = r.brigadaId;
    final nota = TextEditingController();

    try {
      if (siguiente == 'asignado') {
        final recomendaciones = recomendarBrigadas(
          r,
          widget.store.brigadas
              .where((b) => !widget.store.brigadasSinCoordenadas.contains(b.id))
              .toList(),
          widget.store.reportes,
        );

        if (recomendaciones.isEmpty) {
          mostrarError(context, 'No hay brigadas disponibles.');
          return;
        }

        equipo = recomendaciones.first.brigada.id;

        final escogido = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('EcoMatch · Brigadas recomendadas'),
            content: SizedBox(
              width: 430,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final recomendacion in recomendaciones)
                    ListTile(
                      title: Text(recomendacion.brigada.nombre),
                      subtitle: Text(
                        '${recomendacion.kilometros.toStringAsFixed(1)} km · '
                        '${recomendacion.brigada.miembros} integrantes',
                      ),
                      trailing: Text('${recomendacion.puntuacion}/100'),
                      onTap: () => Navigator.pop(ctx, recomendacion.brigada.id),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );

        if (!mounted || escogido == null) return;

        equipo = escogido;
      }

      if (siguiente == 'en_revision' ||
          siguiente == 'cerrado' ||
          siguiente == 'descartado' ||
          (r.estado == 'en_revision' && siguiente == 'en_proceso')) {
        if (!mounted) return;

        final aceptado = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Cambiar a ${estadoNombre(siguiente)}'),
            content: TextField(
              controller: nota,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observación obligatoria',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (nota.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );

        if (!mounted || aceptado != true) return;
      }

      await widget.store.cambiarEstado(
        r,
        siguiente,
        brigadaId: equipo,
        comentario: nota.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado y registrado en el historial.'),
        ),
      );

      await _refrescarHistorial();
    } catch (e) {
      if (mounted) {
        mostrarError(context, e);
      }
    } finally {
      nota.dispose();
    }
  }

  Future<void> _adjuntar(String id, String fase) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      await widget.store.subirFotoReporte(id, fase, picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotografía incorporada a la incidencia.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final coincidencias = widget.store.reportes.where(
        (r) => r.id == widget.id,
      );
      if (coincidencias.isEmpty) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyEco(
            titulo: 'Reporte no encontrado',
            descripcion: 'Es posible que se haya eliminado.',
          ),
        );
      }
      final r = coincidencias.first;
      final admin = widget.store.esAdmin;
      final lider =
          r.brigadaId.isNotEmpty && widget.store.gestionaBrigada(r.brigadaId);
      final acciones = <String>[];
      if (admin && r.estado == 'pendiente') {
        acciones.addAll(['validado', 'descartado']);
      }
      if (admin && r.estado == 'validado') {
        acciones.addAll(['asignado', 'descartado']);
      }
      if ((admin || lider) && r.estado == 'asignado') {
        acciones.add('en_proceso');
      }
      if ((admin || lider) && r.estado == 'en_proceso') {
        acciones.add('en_revision');
      }
      if (admin && r.estado == 'en_revision') {
        acciones.addAll(['cerrado', 'en_proceso']);
      }
      final equipo = widget.store.brigadas.where((b) => b.id == r.brigadaId);
      final movs = widget.store.historialDe(r.id);
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de incidencia')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                EcoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EstadoChip(estado: r.estado),
                      const SizedBox(height: 15),
                      Text(
                        r.titulo,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: EcoColors.forest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(r.descripcion, style: const TextStyle(height: 1.5)),
                      const Divider(height: 30),
                      _detalle('Ubicación', '${r.direccion}, ${r.comuna}'),
                      _detalle('Tipo', r.tipo),
                      _detalle('Gravedad', '${r.gravedad}/5'),
                      _detalle(
                        'Prioridad orientativa',
                        '${r.prioridad}/100 · ${prioridadEtiqueta(r.prioridad)}',
                      ),
                      _detalle(
                        'Brigada asignada',
                        equipo.isEmpty ? 'Sin asignar' : equipo.first.nombre,
                      ),
                      _detalle(
                        'Creado',
                        '${r.creadoEn.day}/${r.creadoEn.month}/${r.creadoEn.year}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                const EcoSection(
                  title: 'Evidencias fotográficas',
                  subtitle:
                      'Fotografías del problema y de la limpieza para su revisión.',
                ),
                if (widget.store.evidenciasDe(r.id).isEmpty)
                  const EcoPanel(
                    child: Text('Todavía no hay fotografías registradas.'),
                  ),
                for (final item in widget.store.evidenciasDe(r.id)) ...[
                  EcoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['fase'] == 'inicial'
                              ? 'ANTES · Reporte inicial'
                              : 'DESPUÉS · Limpieza',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<String>(
                          future: widget.store.fotos.urlTemporal(
                            '${item['storage_path']}',
                          ),
                          builder: (context, snapshot) => snapshot.hasData
                              ? Image.network(
                                  snapshot.data!,
                                  height: 230,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) =>
                                      const Text(
                                        'No se pudo cargar la imagen.',
                                      ),
                                )
                              : snapshot.hasError
                              ? const Text('No se pudo autorizar la imagen.')
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (['pendiente', 'validado'].contains(r.estado) &&
                    (r.creadorUid == widget.store.uid || admin))
                  OutlinedButton.icon(
                    onPressed: () => _adjuntar(r.id, 'inicial'),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Añadir evidencia inicial'),
                  ),
                if ((admin || lider) &&
                    [
                      'asignado',
                      'en_proceso',
                      'en_revision',
                    ].contains(r.estado))
                  OutlinedButton.icon(
                    onPressed: () => _adjuntar(r.id, 'posterior'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Adjuntar fotografía posterior'),
                  ),
                if (admin && widget.store.validacionesDe(r.id).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const EcoSection(title: 'Revisiones administrativas'),
                  for (final validacion in widget.store.validacionesDe(r.id))
                    EcoPanel(
                      child: ListTile(
                        leading: Icon(
                          validacion['resultado'] == 'aprobada'
                              ? Icons.verified_rounded
                              : Icons.keyboard_return_rounded,
                          color: EcoColors.green,
                        ),
                        title: Text(
                          validacion['resultado'] == 'aprobada'
                              ? 'Limpieza aprobada'
                              : 'Devuelta a ejecución',
                        ),
                        subtitle: Text('${validacion['observacion']}'),
                      ),
                    ),
                ],
                const SizedBox(height: 17),
                if (acciones.isNotEmpty) ...[
                  const EcoSection(title: 'Acciones de gestión'),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final a in acciones)
                        FilledButton.icon(
                          onPressed: () => ejecutar(r, a),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(estadoNombre(a)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                const EcoSection(
                  title: 'Historial y trazabilidad',
                  subtitle: 'Registro de cambios de estado y responsables',
                ),
                if (consultandoHistorial)
                  const Center(child: CircularProgressIndicator()),
                if (movs.isEmpty)
                  const EcoPanel(child: Text('Sin movimientos registrados.')),
                for (final m in movs) ...[
                  EcoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${estadoNombre(m.anterior)} → ${estadoNombre(m.nuevo)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.fecha.day}/${m.fecha.month}/${m.fecha.year} · ${m.autorUid}',
                          style: const TextStyle(
                            color: EcoColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (m.comentario.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(m.comentario),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _detalle(String titulo, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 155,
          child: Text(
            titulo,
            style: const TextStyle(
              color: EcoColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(valor)),
      ],
    ),
  );
}
