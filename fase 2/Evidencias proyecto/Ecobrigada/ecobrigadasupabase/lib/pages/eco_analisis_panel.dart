import 'dart:math';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/eco_analisis.dart';
import '../core/reincidencia_lugares.dart';
import '../core/store.dart';
import '../widgets/common.dart';

/// EcoAnálisis se incluye dentro de EcoImpacto para no añadir otra pestaña.
/// Los agregados se calculan sobre los reportes ya cargados por EcoStore.
class EcoAnalisisPanel extends StatelessWidget {
  final EcoStore store;
  const EcoAnalisisPanel({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final zonas = detectarEcoZonas(store.reportes);
    final reincidencias = detectarEcoReincidencia(store.reportes);
    final semanas = calcularEcoTendencias(store.reportes, referencia: ahora);
    final alertas = calcularEcoAlertas(store.reportes, referencia: ahora);
    final reaparicionesAnteriores = analizarReaparicionLugares(
      store.historialLugares, store.lugaresOriginales);
    final promedioReaparicion = reincidencias.isEmpty ? null :
      reincidencias.map((r) => r.nuevoReporte.creadoEn
        .difference(r.incidenciaAnterior.cerradoEn!).inHours).reduce((a,b)=>a+b)
        / (reincidencias.length * 24);
    final ultima = semanas.last;
    final anterior = semanas[semanas.length - 2];
    final admin = store.esAdmin;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const EcoSection(
        title: 'EcoAnálisis',
        subtitle: 'Detección territorial, reincidencias, tendencias y plazos.',
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _miniIndicador(Icons.hub_outlined, '${zonas.length}', 'Sectores agrupados'),
        _miniIndicador(Icons.replay_circle_filled_outlined,
            '${reincidencias.length}', 'Posibles reincidencias'),
        _miniIndicador(Icons.monitor_heart_outlined,
            '${ultima.reportados}', 'Reportes esta semana'),
        _miniIndicador(Icons.warning_amber_rounded,
            '${alertas.where((a) => a.vencida).length}', 'Plazos vencidos'),
      ]),
      const SizedBox(height: 16),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoTendencias', Icons.trending_up_rounded,
          'Evolución semanal de reportes y cierres; media móvil de 3 semanas.'),
        const SizedBox(height: 14),
        _graficoSemanal(semanas),
        const SizedBox(height: 12),
        Text(
          anterior.reportados == 0
              ? 'La variación porcentual no se calcula porque la semana anterior no tiene reportes.'
              : 'Variación semanal de reportes: '
                '${ultima.cambioPorcentual! >= 0 ? '+' : ''}'
                '${ultima.cambioPorcentual!.toStringAsFixed(1)}%.',
          style: const TextStyle(color: EcoColors.muted, fontSize: 12),
        ),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoZonas', Icons.layers_outlined,
          'Agrupaciones de al menos 3 reportes abiertos a 250 m de proximidad.'),
        const SizedBox(height: 12),
        if (zonas.isEmpty)
          const Text('No hay suficientes reportes abiertos cercanos para detectar zonas. '
              'Esto no significa que el territorio esté libre de residuos.',
              style: TextStyle(color: EcoColors.muted, height: 1.5))
        else
          for (var i = 0; i < zonas.length; i++) ...[
            Row(children: [
              const Icon(Icons.place_outlined, color: EcoColors.green, size: 20),
              const SizedBox(width: 7),
              Expanded(child: Text('Zona ${i + 1} · ${zonas[i].comuna}',
                style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('Índice ${zonas[i].indice}/100',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
            const SizedBox(height: 5),
            Text('${zonas[i].reportesActivos} reportes activos · '
              'atención ${zonas[i].nivel.toLowerCase()} · '
              'radio aproximado ${zonas[i].radioMetros.round()} m',
              style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
            if (admin) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Centro: ${zonas[i].centro.latitude.toStringAsFixed(5)}, '
                '${zonas[i].centro.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: EcoColors.muted)),
            ),
            const SizedBox(height: 12),
          ],
        const Text('Puedes ver los círculos de EcoZonas activando '
          '«Ver zonas críticas» en EcoMapa.',
          style: TextStyle(fontSize: 11, color: EcoColors.muted)),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoReincidencia', Icons.repeat_rounded,
          'Posibles nuevos reportes del mismo tipo cerca de una limpieza cerrada.'),
        const SizedBox(height: 12),
        if (reincidencias.isEmpty)
          const Text('Todavía no se observan reincidencias en los registros cargados.',
            style: TextStyle(color: EcoColors.muted))
        else if (!admin)
          Text('Se identificaron ${reincidencias.length} coincidencias espaciales '
            'y temporales para revisión administrativa.',
            style: const TextStyle(color: EcoColors.muted))
        else ...[
          Text('Tiempo promedio observado hasta el nuevo reporte: '
            '${promedioReaparicion!.toStringAsFixed(1)} días',
            style: const TextStyle(fontWeight: FontWeight.w800,
              color: EcoColors.forest)),
          const SizedBox(height: 12),
          for (final r in reincidencias.take(12)) ...[
            Text(r.nuevoReporte.titulo,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Anterior: «${r.incidenciaAnterior.titulo}» · '
              'distancia ${r.distanciaMetros.round()} m · '
              'reaparición en ${r.diasDesdeCierre} días y '
              '${r.nuevoReporte.creadoEn.difference(r.incidenciaAnterior.cerradoEn!).inHours % 24} h',
              style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
          ],
        ],
        if (admin && reincidencias.length > 12)
          Text('Se muestran 12 de ${reincidencias.length} coincidencias.',
              style: const TextStyle(color: EcoColors.muted, fontSize: 11)),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoAlerta', Icons.schedule_send_outlined,
          'Plazos orientativos: prioridad alta 2 días, media 5 y baja 10.'),
        const SizedBox(height: 12),
        if (alertas.isEmpty)
          const Text('No hay reportes vencidos ni próximos a vencer.',
            style: TextStyle(color: EcoColors.muted))
        else if (!admin)
          Text('${alertas.length} reportes necesitan atención por plazo. '
            'Los detalles de gestión se muestran solo a administración.',
            style: const TextStyle(color: EcoColors.muted))
        else
          for (final a in alertas.take(10)) ...[
            Row(children: [
              Icon(a.vencida ? Icons.error_outline : Icons.access_time_rounded,
                color: a.vencida ? Colors.red.shade700 : EcoColors.orange,
                size: 20),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.reporte.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(a.vencida
                      ? 'Vencida hace ${(-a.horasRestantes / 24).toStringAsFixed(1)} días '
                        '· plazo ${a.plazoDias} días'
                      : 'Por vencer en ${a.horasRestantes} horas '
                        '· plazo ${a.plazoDias} días',
                    style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
                ])),
            ]),
            const SizedBox(height: 13),
          ],
        if (admin && alertas.length > 10)
          Text('Se muestran 10 de ${alertas.length} alertas.',
            style: const TextStyle(color: EcoColors.muted, fontSize: 11)),
      ])),
      const SizedBox(height: 14),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('Historial de lugares comunitarios', Icons.history_toggle_off,
          'Cambios de limpio a sucio registrados en la versión anterior.'),
        const SizedBox(height: 12),
        if (reaparicionesAnteriores.isEmpty)
          const Text('Aún no existen ciclos de limpieza y nuevo reporte en los lugares registrados.',
            style: TextStyle(color: EcoColors.muted))
        else ...[
          Text('${reaparicionesAnteriores.length} reapariciones registradas',
            style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final r in reaparicionesAnteriores.take(10)) ...[
            Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Nuevo registro ${r.dias} días después del estado limpio',
              style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
          ],
        ],
        const Text('El intervalo se calcula entre cambios informados por usuarios; '
          'no determina cuándo ocurrió físicamente la contaminación.',
          style: TextStyle(color: EcoColors.muted, fontSize: 11)),
      ])),
      EcoPanel(child: const Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: EcoColors.green),
          SizedBox(width: 9),
          Expanded(child: Text(
            'EcoAnálisis es descriptivo: no predice contaminación futura. '
            'Las zonas y coincidencias son hipótesis para revisión humana. '
            'Los datos proceden de los reportes cargados en la app (hasta 1500 por consulta). Los plazos son orientativos y '
            'no acuerdos de servicio institucionales.',
            style: TextStyle(fontSize: 12, height: 1.5),
          )),
        ],
      )),
      const SizedBox(height: 20),
    ]);
  }

  Widget _miniIndicador(IconData icono, String numero, String etiqueta) {
    return SizedBox(width: 165, child: EcoPanel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: EcoColors.green, size: 19),
        const SizedBox(height: 8),
        Text(numero, style: const TextStyle(fontWeight: FontWeight.w900,
          fontSize: 23, color: EcoColors.forest)),
        const SizedBox(height: 3),
        Text(etiqueta, style: const TextStyle(fontSize: 11,
          color: EcoColors.muted)),
      ]),
    ));
  }

  Widget _encabezado(String titulo, IconData icono, String subtitulo) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, color: EcoColors.green),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 17,
          color: EcoColors.forest, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitulo, style: const TextStyle(
          color: EcoColors.muted, fontSize: 12, height: 1.35)),
      ])),
    ]);
  }

  Widget _graficoSemanal(List<SemanaEco> datos) {
    final maximo = max(1, datos.map((e) => max(e.reportados, e.resueltos)).reduce(max));
    return Column(children: [
      const Row(children: [
        Icon(Icons.circle, color: EcoColors.green, size: 11),
        SizedBox(width: 5), Text('Reportados', style: TextStyle(fontSize: 11)),
        SizedBox(width: 15),
        Icon(Icons.circle, color: EcoColors.orange, size: 11),
        SizedBox(width: 5), Text('Resueltos', style: TextStyle(fontSize: 11)),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final semana in datos)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Column(children: [
                Text('${semana.reportados}/${semana.resueltos}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                SizedBox(height: 98, child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _barra(semana.reportados, maximo, EcoColors.green),
                    const SizedBox(width: 4),
                    _barra(semana.resueltos, maximo, EcoColors.orange),
                  ])),
                const SizedBox(height: 5),
                Text('${semana.inicio.day}/${semana.inicio.month}',
                  style: const TextStyle(color: EcoColors.muted, fontSize: 11)),
                Text('MM ${semana.promedioMovil.toStringAsFixed(1)}',
                  style: const TextStyle(color: EcoColors.muted, fontSize: 10)),
              ])),
          ]),
      ),
    ]);
  }

  Widget _barra(int valor, int maximo, Color color) => Container(
    width: 19, height: valor == 0 ? 3 : max(4.0, valor / maximo * 92),
    decoration: BoxDecoration(color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
  );
}
