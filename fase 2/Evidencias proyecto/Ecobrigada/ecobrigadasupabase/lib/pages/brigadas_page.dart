import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/design.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import 'mapa_page.dart';
import 'chat_brigada_page.dart';

class EcoBrigadas extends StatelessWidget {
  final EcoStore store;
  const EcoBrigadas({super.key, required this.store});

  Future<void> _crearJornada(BuildContext context) async {
    final gestionables = store.brigadas.where((b) => store.gestionaBrigada(b.id)).toList();
    if (gestionables.isEmpty) return;
    final titulo = TextEditingController();
    final lugar = TextEditingController();
    String equipo = gestionables.first.id;
    var fecha = DateTime.now().add(const Duration(days: 3));
    final ok = await showDialog<bool>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Programar jornada'),
        content: SizedBox(width: 440, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Nombre de la actividad')),
            const SizedBox(height: 12),
            TextField(controller: lugar, decoration: const InputDecoration(labelText: 'Lugar')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: equipo,
              decoration: const InputDecoration(labelText: 'Brigada'),
              items: gestionables.map((b) => DropdownMenuItem(
                value: b.id, child: Text(b.nombre))).toList(),
              onChanged: (v) => equipo = v ?? equipo),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: ctx,
                initialDate: fecha, firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setD(() => fecha = d);
            }, icon: const Icon(Icons.calendar_month),
              label: Text('${fecha.day}/${fecha.month}/${fecha.year}')),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Programar')),
        ],
      )));
    if (ok == true) {
      try { await store.crearJornada(titulo: titulo.text, brigadaId: equipo,
        lugar: lugar.text, fecha: fecha);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jornada registrada.')));
      } catch (e) { if (context.mounted) mostrarError(context, e); }
    }
    titulo.dispose(); lugar.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 34), children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Brigadas ambientales', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, color: EcoColors.forest)),
            Text('Equipos que transforman las comunidades',
              style: TextStyle(color: EcoColors.muted, fontSize: 12)),
          ])),
        if (store.esAdmin) IconButton.filledTonal(tooltip: 'Crear brigada',
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => NuevaBrigadaPage(store: store))),
          icon: const Icon(Icons.add)),
      ]),
      const SizedBox(height: 22),
      const EcoSection(title: 'Equipos comunitarios'),
      if (store.brigadas.isEmpty) const EmptyEco(titulo: 'Aún no hay brigadas',
        descripcion: 'Un administrador puede registrar la primera.'),
      for (final b in store.brigadas) ...[
        InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetalleBrigadaPage(store: store, brigadaId: b.id))),
          child: EcoPanel(child: Row(children: [
          Container(width: 57, height: 57,
            decoration: BoxDecoration(color: EcoColors.mint,
              borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.diversity_3_rounded,
              color: EcoColors.green, size: 31)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.nombre, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: EcoColors.forest)),
              const SizedBox(height: 5),
              Text(b.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
              const SizedBox(height: 7),
              Wrap(spacing: 12, children: [
                Text('📍 ${b.comuna}', style: const TextStyle(fontSize: 11)),
                Text('👥 ${b.miembros} integrante(s)',
                  style: const TextStyle(fontSize: 11)),
              ]),
            ])),
            const SizedBox(width: 6),
            Icon(b.disponible ? Icons.check_circle_rounded : Icons.pause_circle,
              color: b.disponible ? EcoColors.green : EcoColors.orange),
        ]))),
        const SizedBox(height: 9),
        Align(alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DetalleBrigadaPage(store: store, brigadaId: b.id))),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Ver brigada, integrantes y chat'),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 20),
      EcoSection(title: 'Jornadas programadas',
        subtitle: 'Planificación de operativos comunitarios',
        trailing: store.brigadas.any((b) => store.gestionaBrigada(b.id))
          ? TextButton.icon(onPressed: () => _crearJornada(context),
              icon: const Icon(Icons.add), label: const Text('Organizar'))
          : null),
      if (store.jornadas.isEmpty) const EmptyEco(titulo: 'Sin jornadas',
        descripcion: 'Las actividades futuras aparecerán aquí.'),
      for (final j in ([...store.jornadas]..sort((a, b) => a.fecha.compareTo(b.fecha)))) ...[
        EcoPanel(child: Row(children: [
          Container(width: 60, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: EcoColors.pale,
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('${j.fecha.day}', style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.w900, color: EcoColors.green)),
              Text('${j.fecha.month}/${j.fecha.year}',
                style: const TextStyle(fontSize: 10, color: EcoColors.muted)),
            ])),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(j.titulo, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(j.lugar, style: const TextStyle(color: EcoColors.muted)),
            ])),
          const Icon(Icons.event_available_outlined, color: EcoColors.green),
        ])),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class NuevaBrigadaPage extends StatefulWidget {
  final EcoStore store;
  const NuevaBrigadaPage({super.key, required this.store});
  @override
  State<NuevaBrigadaPage> createState() => _NuevaBrigadaPageState();
}

class _NuevaBrigadaPageState extends State<NuevaBrigadaPage> {
  final nombre = TextEditingController();
  final comuna = TextEditingController(text: 'Concepción');
  final descripcion = TextEditingController();
  final lider = TextEditingController();
  int miembros = 1;
  LatLng punto = ecoCentro;
  bool cargando = false;
  @override
  void dispose() {
    nombre.dispose(); comuna.dispose(); descripcion.dispose(); lider.dispose();
    super.dispose();
  }
  Future<void> guardar() async {
    setState(() => cargando = true);
    try {
      await widget.store.crearBrigada(nombre: nombre.text,
        comuna: comuna.text, descripcion: descripcion.text,
        miembros: miembros, punto: punto, liderUid: lider.text.trim().isEmpty
          ? null : lider.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally { if (mounted) setState(() => cargando = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear brigada')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 730),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const EcoSection(title: 'Nuevo equipo ambiental'),
        TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre de la brigada')),
        const SizedBox(height: 12),
        TextField(controller: descripcion, decoration: const InputDecoration(labelText: 'Descripción')),
        const SizedBox(height: 12),
        TextField(controller: comuna, decoration: const InputDecoration(labelText: 'Comuna')),
        const SizedBox(height: 12),
        ...[
          TextField(controller: lider, decoration: const InputDecoration(
            labelText: 'UID de líder (Supabase Auth, opcional)')),
          const SizedBox(height: 12),
        ],
        const Text('Los integrantes se registran mediante solicitudes aprobadas.',
          style: TextStyle(color: EcoColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        SelectorPunto(inicial: punto, onChanged: (p) => punto = p),
        const SizedBox(height: 20),
        FilledButton(onPressed: cargando ? null : guardar,
          child: Text(cargando ? 'Guardando...' : 'Crear brigada')),
      ]))),
  );
}


/// Alta de integrantes por solicitud y aprobación, independiente de jornadas.
class DetalleBrigadaPage extends StatefulWidget {
  const DetalleBrigadaPage({super.key, required this.store, required this.brigadaId});
  final EcoStore store;
  final String brigadaId;
  @override
  State<DetalleBrigadaPage> createState() => _DetalleBrigadaPageState();
}

class _DetalleBrigadaPageState extends State<DetalleBrigadaPage> {
  bool cargando = false;
  bool procesando = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    if (mounted) setState(() => cargando = true);
    try {
      await widget.store.cargarParticipacion(widget.brigadaId);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _solicitar() async {
    setState(() => procesando = true);
    try {
      await widget.store.solicitarIngreso(widget.brigadaId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada a la brigada.')));
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  Future<void> _revisar(SolicitudBrigada solicitud, bool aprobar) async {
    setState(() => procesando = true);
    try {
      await widget.store.revisarSolicitud(solicitud, aprobar: aprobar);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aprobar ? 'Integrante incorporado.' : 'Solicitud rechazada.')));
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final s = widget.store;
      final equipos = s.brigadas.where((b) => b.id == widget.brigadaId);
      if (equipos.isEmpty) return const Scaffold(body: Center(
        child: Text('No se encontró la brigada.')));
      final b = equipos.first;
      final encargado = s.gestionaBrigada(b.id);
      final solicitud = s.miSolicitud(b.id);
      final misIntegrantes = s.integrantesDe(b.id);
      final solicitudesPendientes = s.solicitudesDe(b.id)
        .where((r) => r.estado == 'pendiente').toList();
      final soyLider = b.liderUid == s.uid;
      final lideres = misIntegrantes.where((m) => m.uid == b.liderUid);
      final liderNombre = lideres.isEmpty ? 'Por confirmar' : lideres.first.nombre;

      return Scaffold(
        appBar: AppBar(title: Text(b.nombre), actions: [
          IconButton(tooltip: 'Actualizar', onPressed: cargando ? null : _recargar,
            icon: const Icon(Icons.refresh_rounded)),
        ]),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.nombre, style: const TextStyle(fontSize: 23,
                  fontWeight: FontWeight.w900, color: EcoColors.forest)),
                const SizedBox(height: 7),
                Text(b.descripcion),
                const SizedBox(height: 9),
                Text('📍 ${b.comuna}', style: const TextStyle(color: EcoColors.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 6, children: [
                  Text('👥 ${b.miembros} integrante(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Estado: ${b.disponible ? 'Disponible' : 'Pausada'}',
                    style: const TextStyle(color: EcoColors.muted)),
                ]),
                const SizedBox(height: 8),
                Text('Responsable: $liderNombre',
                  style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
                if (b.nombre.toLowerCase().contains('ficticia'))
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('Brigada de prueba: equipo y ubicación ficticios.',
                      style: TextStyle(color: EcoColors.orange, fontSize: 12))),
                if (soyLider) const Padding(padding: EdgeInsets.only(top: 7),
                  child: Text('Eres líder de esta brigada.',
                    style: TextStyle(color: EcoColors.green))),
              ])),
            const SizedBox(height: 18),
            const EcoSection(title: 'Chat grupal',
              subtitle: 'Los mensajes son privados y están separados por brigada.'),
            if (s.puedeChatear(b.id)) ...[
              EcoPanel(child: Row(children: [
                const Icon(Icons.forum_rounded, color: EcoColors.green, size: 31),
                const SizedBox(width: 12),
                const Expanded(child: Text(
                  'Puedes leer y enviar mensajes con los integrantes de esta brigada.',
                  style: TextStyle(fontSize: 12))),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatBrigadaPage(store: s, brigadaId: b.id))),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Abrir chat')),
              ])),
            ] else
              const EcoPanel(child: Row(children: [
                Icon(Icons.lock_outline_rounded, color: EcoColors.muted),
                SizedBox(width: 12),
                Expanded(child: Text(
                  'Chat reservado. Solicita ingreso; el chat se habilitará '
                  'cuando te aprueben. Los administradores pueden ver cualquier chat.',
                  style: TextStyle(fontSize: 12))),
              ])),
            const SizedBox(height: 18),
            if (cargando) const LinearProgressIndicator(),
            if (!encargado) ...[
              const EcoSection(title: 'Participar en esta brigada',
                subtitle: 'El líder revisará tu solicitud antes de incorporarte.'),
              if (!s.autenticado) const EcoPanel(child: Text(
                'Debes iniciar sesión para solicitar tu incorporación.'))
              else if (s.soyIntegrante(b.id))
                const EcoPanel(child: Text('✅ Ya perteneces a esta brigada.'))
              else if (solicitud?.estado == 'pendiente')
                const EcoPanel(child: Text('⏳ Tu solicitud está pendiente de aprobación.'))
              else if (solicitud?.estado == 'aprobada')
                const EcoPanel(child: Text('✅ Solicitud aprobada.'))
              else ...[
                if (solicitud?.estado == 'rechazada')
                  const Padding(padding: EdgeInsets.only(bottom: 10),
                    child: Text('Tu solicitud anterior fue rechazada. Puedes enviar otra.')),
                FilledButton.icon(onPressed: (procesando || cargando) ? null : _solicitar,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Solicitar ingreso')),
              ],
            ],
            if (encargado) ...[
              const EcoSection(title: 'Solicitudes pendientes',
                subtitle: 'Solo el líder de este equipo o administración puede aprobar.'),
              if (solicitudesPendientes.isEmpty)
                const EcoPanel(child: Text('No hay solicitudes pendientes.')),
              for (final solicitud in solicitudesPendientes) ...[
                EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(solicitud.nombre, style: const TextStyle(
                      fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('Solicitada: ${solicitud.fechaSolicitud.day}/'
                      '${solicitud.fechaSolicitud.month}/${solicitud.fechaSolicitud.year}',
                      style: const TextStyle(fontSize: 12, color: EcoColors.muted)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, children: [
                      FilledButton.icon(onPressed: procesando ? null : () => _revisar(solicitud, true),
                        icon: const Icon(Icons.check), label: const Text('Aprobar')),
                      OutlinedButton.icon(onPressed: procesando ? null : () => _revisar(solicitud, false),
                        icon: const Icon(Icons.close), label: const Text('Rechazar')),
                    ]),
                  ])),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 15),
              const EcoSection(title: 'Integrantes confirmados',
                subtitle: 'Miembros incorporados tras una aprobación.'),
              if (misIntegrantes.isEmpty)
                const EcoPanel(child: Text('Aún no hay integrantes registrados.')),
              for (final m in misIntegrantes) ...[
                EcoPanel(child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(m.nombre),
                  subtitle: Text('Incorporado: ${m.fechaIngreso.day}/'
                    '${m.fechaIngreso.month}/${m.fechaIngreso.year}'),
                )),
                const SizedBox(height: 8),
              ],
            ],

          ]),
        )),
      );
    },
  );
}
