import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../core/algorithms.dart';
import '../core/design.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import 'eco_analisis_panel.dart';
import '../services/informe_pdf.dart';

/// Presentación pública: indicadores agregados.
/// Vista administrativa: además muestra desgloses y permite exportar CSV.
class EcoImpacto extends StatelessWidget {
  final EcoStore store;
  const EcoImpacto({super.key, required this.store});

  Future<void> _exportar(BuildContext context) async {
    if (!store.esAdmin) {
      mostrarError(context, StateError('La exportación es exclusiva para administradores.'));
      return;
    }
    try {
      final contenido = generarCsv(store.reportes);
      await FileSaver.instance.saveFile(
        name: 'ecobrigada_reporte_administrativo',
        bytes: Uint8List.fromList(utf8.encode(contenido)),
        fileExtension: 'csv',
        mimeType: MimeType.custom,
        customMimeType: 'text/csv',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe CSV exportado.')));
      }
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = store.esAdmin;
    final total = store.reportes.length;
    final resueltos = store.cerrados;
    final dias = store.reportes
        .where((r) => r.cerradoEn != null)
        .map((r) => r.cerradoEn!.difference(r.creadoEn).inHours / 24)
        .toList();
    final promedio = dias.isEmpty ? 0.0 : dias.reduce((a, b) => a + b) / dias.length;
    final porEstado = <String, int>{};
    final porComuna = <String, int>{};
    for (final r in store.reportes) {
      porEstado[r.estado] = (porEstado[r.estado] ?? 0) + 1;
      porComuna[r.comuna] = (porComuna[r.comuna] ?? 0) + 1;
    }
    final comunas = porComuna.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(admin ? 'EcoImpacto · Administración' : 'EcoImpacto',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: EcoColors.forest)),
              Text(admin ? 'Indicadores operativos y exportación de gestión'
                  : 'Resultados ambientales públicos de nuestra comunidad',
                style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
            ])),
          if (admin) IconButton.filledTonal(
            tooltip: 'Exportar PDF de resultados',
            onPressed: () async {
              try {await InformePdf.exportar(store.reportes, store.brigadas, store.jornadas);}
              catch(e){if(context.mounted) mostrarError(context,e);}
            }, icon: const Icon(Icons.picture_as_pdf_outlined)),
          if (admin) IconButton.filledTonal(
            tooltip: 'Exportar CSV administrativo',
            onPressed: () => _exportar(context),
            icon: const Icon(Icons.download_rounded)),
        ]),
        const SizedBox(height: 18),
        if (!admin) ...[
          EcoPanel(child: Row(children: [
            const Icon(Icons.public, color: EcoColors.green),
            const SizedBox(width: 12),
            const Expanded(child: Text(
              'Vista comunitaria: muestra estadísticas generales. '
              'Los informes detallados están reservados para administradores.',
              style: TextStyle(height: 1.5))),
          ])),
          const SizedBox(height: 17),
        ],
        responsiveWrap([
          Indicador(titulo: 'Incidencias registradas', valor: '$total',
            icono: Icons.assignment_outlined),
          Indicador(titulo: 'Incidencias resueltas', valor: '$resueltos',
            icono: Icons.task_alt_rounded),
          Indicador(titulo: 'Tasa de resolución',
            valor: total == 0 ? '0%' : '${(resueltos * 100 / total).round()}%',
            icono: Icons.track_changes_rounded),
          Indicador(titulo: 'Jornadas programadas', valor: '${store.jornadas.length}',
            icono: Icons.event_available_rounded),
        ]),
        const SizedBox(height: 24),
        EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado general de las incidencias',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            for (final e in porEstado.entries) ...[
              _barra(estadoNombre(e.key), e.value, total),
              const SizedBox(height: 15),
            ],
            if (total == 0) const Text('Aún no hay datos para visualizar.'),
          ])),
        const SizedBox(height: 20),
        if (admin) ...[
          const EcoSection(title: 'Panel exclusivo de administración',
            subtitle: 'Detalles operativos, distribución territorial e informes.'),
          responsiveWrap([
            Indicador(titulo: 'Casos activos', valor: '${store.activos}',
              icono: Icons.pending_actions_rounded),
            Indicador(titulo: 'Tiempo medio de resolución',
              valor: '${promedio.toStringAsFixed(1)} días',
              icono: Icons.schedule_rounded),
            Indicador(titulo: 'Brigadas registradas',
              valor: '${store.brigadas.length}',
              icono: Icons.groups_rounded),
          ]),
          const SizedBox(height: 20),
          EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Incidencias por comuna',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              for (final e in comunas.take(10)) ...[
                _barra(e.key, e.value, total),
                const SizedBox(height: 15),
              ],
              if (comunas.isEmpty) const Text('Sin incidencias todavía.'),
            ])),
          const SizedBox(height: 18),
          EcoPanel(child: Row(children: [
            const Icon(Icons.file_download_outlined, color: EcoColors.green),
            const SizedBox(width: 12),
            const Expanded(child: Text(
              'Descarga la tabla detallada de reportes en CSV para análisis externo.')),
            FilledButton(onPressed: () => _exportar(context),
              child: const Text('Exportar')),
          ])),
          const SizedBox(height: 18),
        ],
        // EcoAnálisis aprovecha los datos existentes sin colecciones nuevas.
        EcoAnalisisPanel(store: store),
        EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, color: EcoColors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Sobre estos resultados',
                style: TextStyle(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 12),
            const Text('Las cifras se calculan a partir de los reportes del sistema. '
              'No representan una medición directa de contaminación ni '
              'una predicción de inteligencia artificial.',
              style: TextStyle(height: 1.5)),

          ])),
      ],
    );
  }

  Widget _barra(String titulo, int valor, int total) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(titulo,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        Text('$valor', style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 7),
      ClipRRect(borderRadius: BorderRadius.circular(7),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : valor / total,
          backgroundColor: EcoColors.pale,
          color: EcoColors.green, minHeight: 9)),
    ],
  );
}
