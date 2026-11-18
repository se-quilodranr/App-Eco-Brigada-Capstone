import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';
import '../widgets/common.dart';

class EcoHome extends StatelessWidget {
  final EcoStore store;
  final void Function(int) irA;
  final VoidCallback nuevoReporte;
  final VoidCallback irComunidad;
  final void Function(String) verReporte;
  const EcoHome({super.key, required this.store, required this.irA,
    required this.nuevoReporte, required this.verReporte, required this.irComunidad});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 18.0 : 34.0;
    return ListView(padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 18),
      children: [
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hola, ${store.nombreUsuario.split(' ').first} 👋',
              style: const TextStyle(color: EcoColors.muted,
                fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 5),
            const Text('Cambiemos nuestro entorno',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 25,
                color: EcoColors.forest, letterSpacing: -1)),
          ])),
          if (width >= 640)
            OutlinedButton.icon(onPressed: () => irA(4),
              icon: const Icon(Icons.insights_rounded), label: const Text('Ver impacto')),
        ]),
        const SizedBox(height: 22),
        _HeroEco(onReportar: nuevoReporte, onMapa: () => irA(1)),
        const SizedBox(height: 26),
        const EcoSection(title: 'Nuestro impacto, en un vistazo',
          subtitle: 'Indicadores de la plataforma'),
        responsiveWrap([
          Indicador(titulo: 'Incidencias activas', valor: '${store.activos}',
            icono: Icons.warning_amber_rounded, acento: EcoColors.orange),
          Indicador(titulo: 'Casos resueltos', valor: '${store.cerrados}',
            icono: Icons.verified_outlined),
          Indicador(titulo: 'Brigadas disponibles',
            valor: '${store.brigadas.where((b) => b.disponible).length}',
            icono: Icons.groups_outlined),
          Indicador(titulo: 'Jornadas organizadas', valor: '${store.jornadas.length}',
            icono: Icons.event_available_outlined),
        ], width: 220),
        const SizedBox(height: 31),
        const EcoSection(title: '¿Qué quieres hacer hoy?',
          subtitle: 'Participa y ayuda a transformar tu comunidad'),
        LayoutBuilder(builder: (ctx, box) {
          final compact = box.maxWidth < 720;
          final widgets = [
            _AccionCard(color: const Color(0xFFE8F5E9),
              icon: Icons.add_location_alt_outlined, title: 'Reportar un problema',
              subtitle: 'Registra un punto de contaminación cercano.',
              onTap: nuevoReporte),
            _AccionCard(color: const Color(0xFFFFF3E6),
              icon: Icons.map_outlined, title: 'Explorar EcoMapa',
              subtitle: 'Descubre incidencias de tu sector.', onTap: () => irA(1)),
            _AccionCard(color: const Color(0xFFE8EFFB),
              icon: Icons.diversity_3_outlined, title: 'Unirme a una brigada',
              subtitle: 'Conoce equipos y próximas actividades.',
              onTap: () => irA(3)),
          ];
          if (compact) return Column(children: [for (final w in widgets) ...[
            w, const SizedBox(height: 12),
          ]]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final w in widgets) Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 12), child: w))]);
        }),
        const SizedBox(height: 16),
        EcoPanel(child: Row(children: [
          Container(padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: EcoColors.mint,
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_stories_outlined, color: EcoColors.green)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comunidad y reciclaje',
                style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Publicaciones, tutoriales y experiencias que ya tenías en Supabase.',
                style: TextStyle(fontSize: 12,color: EcoColors.muted)),
            ])),
          TextButton.icon(onPressed: irComunidad,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Abrir')),
        ])),
        const SizedBox(height: 30),
        LayoutBuilder(builder: (ctx, box) {
          final reportes = store.recientes.take(3).toList();
          final contenido = Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EcoSection(title: 'Actividad reciente',
                trailing: TextButton(onPressed: () => irA(2),
                  child: const Text('Ver todos'))),
              if (reportes.isEmpty)
                const EmptyEco(titulo: 'Aún no hay reportes',
                  descripcion: 'El primer reporte puede ser el tuyo.'),
              for (final r in reportes) ...[
                ReporteTile(reporte: r, onTap: () => verReporte(r.id)),
                const SizedBox(height: 10),
              ],
            ]);
          final proximas = [...store.jornadas]..sort((a, b) => a.fecha.compareTo(b.fecha));
          final actividades = Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EcoSection(title: 'Próximas jornadas',
                trailing: TextButton(onPressed: () => irA(3),
                  child: const Text('Explorar'))),
              EcoPanel(child: Column(children: [
                for (final j in proximas.where((e) => e.fecha.isAfter(DateTime.now())).take(3)) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: EcoColors.mint,
                        borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.calendar_month_outlined,
                        color: EcoColors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text('${j.lugar} · ${j.fecha.day}/${j.fecha.month}/${j.fecha.year}',
                          style: const TextStyle(fontSize: 12,
                            color: EcoColors.muted)),
                      ])),
                  ]),
                  const Divider(height: 27),
                ],
                if (!proximas.any((e) => e.fecha.isAfter(DateTime.now())))
                  const Text('Próximamente habrá nuevas jornadas.'),
              ])),
            ]);
          if (box.maxWidth < 800) return Column(children: [contenido,
            const SizedBox(height: 25), actividades]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 3, child: contenido),
              const SizedBox(width: 24), Expanded(flex: 2, child: actividades)]);
        }),
        const SizedBox(height: 32),
        const Center(child: Text('EcoBrigada · Del reporte a la acción',
          style: TextStyle(color: EcoColors.muted, fontSize: 12))),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _HeroEco extends StatelessWidget {
  final VoidCallback onReportar, onMapa;
  const _HeroEco({required this.onReportar, required this.onMapa});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [EcoColors.forest,
          Color(0xFF14634D)], begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(27)),
      child: Stack(children: [
        Positioned(right: -60, top: -94, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 42)))),
        Positioned(right: 65, bottom: -65, child: Container(width: 190, height: 190,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: EcoColors.lime.withValues(alpha: 0.08)))),
        Padding(padding: EdgeInsets.all(compact ? 23 : 36), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(30)),
                child: const Text('🌱  COMUNIDAD QUE TRANSFORMA',
                  style: TextStyle(color: EcoColors.lime, fontSize: 10,
                    fontWeight: FontWeight.w900, letterSpacing: 1.2))),
              const SizedBox(height: 20),
              Text('Un pequeño reporte,\nun gran cambio.',
                style: TextStyle(fontSize: compact ? 31 : 45,
                  color: Colors.white, fontWeight: FontWeight.w900,
                  letterSpacing: -1.3, height: 1.1)),
              const SizedBox(height: 13),
              const Text('Reporta, participa y descubre cómo tu comunidad\npuede recuperar sus espacios.',
                style: TextStyle(fontSize: 14, color: Color(0xFFD5E9DD), height: 1.5)),
              const SizedBox(height: 23),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(onPressed: onReportar,
                  style: FilledButton.styleFrom(backgroundColor: EcoColors.lime,
                    foregroundColor: EcoColors.forest),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Crear reporte')),
                OutlinedButton.icon(onPressed: onMapa,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54)),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Ver EcoMapa')),
              ]),
            ])),
          if (!compact) ...[
            const SizedBox(width: 12),
            SizedBox(width: 168, child: Column(children: [
              Icon(Icons.forest_rounded, size: 115,
                color: EcoColors.lime.withValues(alpha: 0.9)),
              const SizedBox(height: 8),
              const Text('CADA ACCIÓN CUENTA', style: TextStyle(
                color: EcoColors.lime, fontWeight: FontWeight.w800,
                fontSize: 10, letterSpacing: 1.2)),
            ])),
          ],
        ])),
      ]),
    );
  }
}

class _AccionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _AccionCard({required this.color, required this.icon,
    required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: color, borderRadius: BorderRadius.circular(20),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: EcoColors.forest, size: 30),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w900, color: EcoColors.forest)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: EcoColors.muted,
            fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          const Row(children: [Text('Explorar',
            style: TextStyle(color: EcoColors.green, fontWeight: FontWeight.w800)),
            SizedBox(width: 5), Icon(Icons.arrow_forward_rounded,
              color: EcoColors.green, size: 17)]),
        ])),
    ),
  );
}
