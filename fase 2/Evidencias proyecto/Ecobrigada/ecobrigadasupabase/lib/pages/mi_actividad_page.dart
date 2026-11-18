import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import 'brigadas_page.dart';
import 'incidencias_page.dart';

/// Listados personales; nunca se sustituyen por estadísticas globales.
class MiActividadPage extends StatelessWidget {
  final EcoStore store;
  /// reportes, lidero, integrante.
  final String tipo;
  const MiActividadPage({super.key, required this.store, required this.tipo});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final misReportes = tipo == 'reportes';
      final titulo = switch (tipo) {
        'reportes' => 'Mis reportes',
        'lidero' => 'Brigadas que lidero',
        _ => 'Brigadas a las que pertenezco',
      };
      final reportes = store.recientes
        .where((r) => r.creadorUid == store.uid).toList();
      final brigadas = store.brigadas.where((b) => tipo == 'lidero'
        ? b.liderUid == store.uid
        : b.liderUid != store.uid && store.soyIntegrante(b.id)).toList();
      return Scaffold(
        appBar: AppBar(title: Text(titulo), actions: [
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh),
            onPressed: () => store.refrescar()),
        ]),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            EcoSection(title: titulo,
              subtitle: misReportes
                ? '${reportes.length} incidencias creadas por tu cuenta'
                : '${brigadas.length} brigadas asociadas a tu cuenta'),
            if (misReportes && reportes.isEmpty)
              const EmptyEco(titulo: 'Aún no tienes reportes',
                descripcion: 'Crea tu primer reporte ambiental.'),
            if (!misReportes && brigadas.isEmpty)
              EmptyEco(titulo: 'Sin brigadas en esta categoría',
                descripcion: tipo == 'lidero'
                  ? 'Todavía no lideras ninguna brigada.'
                  : 'Cuando aprueben tu solicitud aparecerá aquí.'),
            if (misReportes)
              for (final r in reportes) ...[
                ReporteTile(reporte: r,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetalleReportePage(store: store, id: r.id)))),
                const SizedBox(height: 10),
              ]
            else
              for (final b in brigadas) ...[
                EcoPanel(child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: EcoColors.mint,
                    child: Icon(Icons.groups, color: EcoColors.green)),
                  title: Text(b.nombre, style: const TextStyle(
                    fontWeight: FontWeight.bold)),
                  subtitle: Text('${b.comuna} · ${b.miembros} integrantes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetalleBrigadaPage(
                      store: store, brigadaId: b.id))),
                )),
                const SizedBox(height: 10),
              ],
          ]))),
      );
    },
  );
}
