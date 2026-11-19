import 'dart:math';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/eco_analisis.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../widgets/common.dart';

/// Analítica descriptiva sobre los datos efectivamente cargados por EcoStore.
/// La navegación a listados completos no solicita datos adicionales ni cambia RLS.
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
    final ultima = semanas.last;
    final anterior = semanas[semanas.length - 2];
    final admin = store.esAdmin;
    final todosReportados = semanas.fold<int>(0, (s, e) => s + e.reportados);
    final todosResueltos = semanas.fold<int>(0, (s, e) => s + e.resueltos);
    final maxSemana = semanas.reduce((a, b) => a.reportados >= b.reportados ? a : b);
    final activosEnZonas = zonas.fold<int>(0, (s, z) => s + z.reportesActivos);
    final altos = zonas.where((z) => z.nivel == 'Alta').length;
    final vencidas = alertas.where((a) => a.vencida).length;
    final proximas = alertas.length - vencidas;
    final promedioDias = reincidencias.isEmpty ? 0.0 :
      reincidencias.map((r) => r.nuevoReporte.creadoEn
        .difference(r.incidenciaAnterior.cerradoEn!).inHours / 24.0)
        .reduce((a, b) => a + b) / reincidencias.length;
    final promedioDistancia = reincidencias.isEmpty ? 0.0 :
      reincidencias.map((r) => r.distanciaMetros).reduce((a, b) => a + b)
        / reincidencias.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const EcoSection(
        title: 'EcoAnálisis',
        subtitle: 'Comprende dónde se concentran los reportes, cómo evolucionan y qué requiere atención.',
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _miniIndicador(Icons.hub_outlined, '${zonas.length}', 'Sectores agrupados',
          'Conjuntos de al menos tres incidencias abiertas a corta distancia.'),
        _miniIndicador(Icons.replay_circle_filled_outlined,
          '${reincidencias.length}', 'Posibles reincidencias',
          'Nuevos reportes del mismo tipo cerca de un caso cerrado.'),
        _miniIndicador(Icons.monitor_heart_outlined,
          '${ultima.reportados}', 'Reportes esta semana',
          'Incidencias registradas desde el inicio de esta semana.'),
        _miniIndicador(Icons.warning_amber_rounded,
          '$vencidas', 'Plazos vencidos',
          'Casos abiertos que superaron el plazo orientativo de atención.'),
      ]),
      const SizedBox(height: 16),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoTendencias', Icons.trending_up_rounded,
          'Compara la entrada de reportes y los cierres por semana. MM corresponde a la media móvil de tres semanas.'),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _dato('Reportes en 8 semanas', '$todosReportados'),
          _dato('Cierres en 8 semanas', '$todosResueltos'),
          _dato('Semana de más reportes',
            '${maxSemana.reportados} · ${_fecha(maxSemana.inicio)}'),
        ]),
        const SizedBox(height: 14),
        _graficoSemanal(semanas),
        const SizedBox(height: 12),
        Text(anterior.reportados == 0
          ? 'No se calcula variación relativa: la semana previa registró cero incidencias.'
          : 'Cambio respecto de la semana anterior: '
            '${ultima.cambioPorcentual! >= 0 ? '+' : ''}'
            '${ultima.cambioPorcentual!.toStringAsFixed(1)} % '
            '(${anterior.reportados} → ${ultima.reportados} reportes).',
          style: const TextStyle(color: EcoColors.forest, fontSize: 12,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        const Text('Los reportes y los cierres pueden corresponder a incidencias distintas. '
          'La media móvil suaviza las oscilaciones para identificar cambios generales; '
          'no es un pronóstico.',
          style: TextStyle(color: EcoColors.muted, fontSize: 12, height: 1.5)),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoZonas', Icons.layers_outlined,
          'Identifica concentraciones territoriales conectando reportes abiertos '
          'separados por un máximo de 250 metros. Cada zona tiene al menos tres reportes.'),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _dato('Zonas detectadas', '${zonas.length}'),
          _dato('Reportes agrupados', '$activosEnZonas'),
          _dato('Zonas de atención alta', '$altos'),
        ]),
        const SizedBox(height: 12),
        if (zonas.isEmpty)
          const Text('No hay reportes abiertos suficientemente cercanos para detectar agrupaciones. '
            'Esto no implica ausencia de problemas ambientales.',
            style: TextStyle(color: EcoColors.muted, height: 1.5))
        else for (var i = 0; i < zonas.length; i++) ...[
          _zona(context, i + 1, zonas[i], admin),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 6),
        const Text('El índice combina cantidad de reportes y gravedad máxima; '
          'no representa una medición física de contaminación. '
          'En EcoMapa puedes activar «Ver zonas críticas» para ubicarlas.',
          style: TextStyle(fontSize: 12, color: EcoColors.muted, height: 1.5)),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoReincidencia', Icons.repeat_rounded,
          'Detecta reportes abiertos del mismo tipo a un máximo de 150 m '
          'de una incidencia previamente cerrada, dentro de 180 días.'),
        const SizedBox(height: 12),
        if (reincidencias.isEmpty)
          const Text('Por ahora no se detectaron coincidencias con estos criterios.',
            style: TextStyle(color: EcoColors.muted))
        else if (!admin)
          Text('Se detectaron ${reincidencias.length} coincidencias para revisión '
            'administrativa. Son indicios espaciales y temporales, no casos confirmados.',
            style: const TextStyle(color: EcoColors.muted, height: 1.4))
        else ...[
          Wrap(spacing: 18, runSpacing: 8, children: [
            _dato('Coincidencias', '${reincidencias.length}'),
            _dato('Reaparición media', '${promedioDias.toStringAsFixed(1)} días'),
            _dato('Distancia media', '${promedioDistancia.round()} m'),
          ]),
          const SizedBox(height: 12),
          ...reincidencias.take(8).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 9), child: _tarjetaReincidencia(r))),
          if (reincidencias.length > 8)
            Text('Vista preliminar: 8 de ${reincidencias.length} coincidencias.',
              style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _TodasReincidencias(resultados: reincidencias))),
            icon: const Icon(Icons.list_alt_rounded),
            label: Text('Ver todos los ${reincidencias.length} resultados'),
          )),
        ],
        const SizedBox(height: 7),
        const Text('Una coincidencia no demuestra que la limpieza anterior haya fallado: '
          'se requiere inspección del lugar, revisión de evidencias y fechas.',
          style: TextStyle(color: EcoColors.muted, fontSize: 12, height: 1.5)),
      ])),
      const SizedBox(height: 14),
      EcoPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _encabezado('EcoAlerta', Icons.schedule_send_outlined,
          'Señala casos abiertos que están vencidos o a 24 horas de vencer. '
          'El plazo orientativo es de 2 días para prioridad alta, 5 para media y 10 para baja.'),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _dato('Alertas detectadas', '${alertas.length}'),
          _dato('Ya vencidas', '$vencidas'),
          _dato('Próximas a vencer', '$proximas'),
        ]),
        const SizedBox(height: 12),
        if (alertas.isEmpty)
          const Text('No hay incidencias vencidas o próximas a vencer.',
            style: TextStyle(color: EcoColors.muted))
        else if (!admin)
          Text('Hay ${alertas.length} incidencias que necesitan revisión de plazos. '
            'El detalle operacional está reservado para administración.',
            style: const TextStyle(color: EcoColors.muted, height: 1.4))
        else ...[
          ...alertas.take(8).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10), child: _tarjetaAlerta(a))),
          if (alertas.length > 8)
            Text('Vista preliminar: 8 de ${alertas.length} alertas.',
              style: const TextStyle(color: EcoColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _TodasAlertas(alertas: alertas))),
            icon: const Icon(Icons.list_alt_rounded),
            label: Text('Ver todas las ${alertas.length} alertas'),
          )),
        ],
        const SizedBox(height: 7),
        const Text('Los plazos son una regla orientativa de priorización y no '
          'compromisos de respuesta de una entidad pública. '
          'Un caso vencido sigue abierto hasta su cierre formal.',
          style: TextStyle(color: EcoColors.muted, fontSize: 12, height: 1.5)),
      ])),
      const SizedBox(height: 14),
      const EcoPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: EcoColors.green),
          SizedBox(width: 9),
          Expanded(child: Text(
            'EcoAnálisis describe únicamente las incidencias cargadas en la aplicación '
            '(máximo 1500 por consulta); pueden incluir registros de demostración. '
            'No confirma contaminación, reincidencias ni predice riesgos futuros. '
            'Los resultados se deben contrastar con inspecciones en terreno.',
            style: TextStyle(fontSize: 12, height: 1.5),
          )),
        ],
      )),
      const SizedBox(height: 20),
    ]);
  }

  Widget _zona(BuildContext context, int numero, ZonaEco zona, bool admin) {
    final ids = zona.reporteIds.toSet();
    final reportes = store.reportes.where((r) => ids.contains(r.id)).toList();
    final tipos = <String, int>{};
    for (final r in reportes) {
      tipos[r.tipo] = (tipos[r.tipo] ?? 0) + 1;
    }
    final tiposOrdenados = tipos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final alta = zona.nivel == 'Alta';
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
        border: Border.all(color: EcoColors.line)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
        leading: Icon(Icons.location_on_outlined,
          color: alta ? Colors.deepOrange : EcoColors.green),
        title: Text('Zona $numero · ${zona.comuna}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        subtitle: Text('${zona.reportesActivos} incidencias abiertas · '
          'Atención ${zona.nivel.toLowerCase()} · índice ${zona.indice}/100',
          style: const TextStyle(fontSize: 11.5, color: EcoColors.muted)),
        children: [
          const Divider(height: 15),
          _lineaDetalle('Radio aproximado', '${zona.radioMetros.round()} m'),
          _lineaDetalle('Mayor gravedad reportada', '${zona.gravedadMaxima}/5'),
          _lineaDetalle('Tipos registrados', tiposOrdenados.isEmpty
            ? 'Sin desglose' : tiposOrdenados.map((t) => '${t.key}: ${t.value}').join(' · ')),
          if (admin) _lineaDetalle('Centro geográfico',
            '${zona.centro.latitude.toStringAsFixed(5)}, '
            '${zona.centro.longitude.toStringAsFixed(5)}'),
          if (admin && reportes.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Ejemplos de reportes en esta zona:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            for (final r in reportes.take(3))
              Align(alignment: Alignment.centerLeft,
                child: Text('• ${r.titulo} · gravedad ${r.gravedad}/5',
                  style: const TextStyle(fontSize: 11.5, color: EcoColors.muted))),
          ],
        ],
      ),
    );
  }

  Widget _miniIndicador(IconData icono, String numero, String etiqueta,
      String descripcion) => SizedBox(width: 174, child: EcoPanel(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, color: EcoColors.green, size: 19),
      const SizedBox(height: 8),
      Text(numero, style: const TextStyle(fontWeight: FontWeight.w900,
        fontSize: 23, color: EcoColors.forest)),
      const SizedBox(height: 3),
      Text(etiqueta, style: const TextStyle(fontSize: 11,
        color: EcoColors.forest, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(descripcion, style: const TextStyle(fontSize: 10.5,
        color: EcoColors.muted, height: 1.4)),
    ]),
  ));

  Widget _encabezado(String titulo, IconData icono, String subtitulo) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, color: EcoColors.green),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 17,
          color: EcoColors.forest, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitulo, style: const TextStyle(
          color: EcoColors.muted, fontSize: 12, height: 1.4)),
      ])),
    ]);

  Widget _graficoSemanal(List<SemanaEco> datos) {
    final maximo = max(1, datos.map((e) => max(e.reportados, e.resueltos)).reduce(max));
    return Column(children: [
      const Row(children: [
        Icon(Icons.circle, color: EcoColors.green, size: 11),
        SizedBox(width: 5), Text('Reportados', style: TextStyle(fontSize: 11)),
        SizedBox(width: 15),
        Icon(Icons.circle, color: EcoColors.orange, size: 11),
        SizedBox(width: 5), Text('Cerrados', style: TextStyle(fontSize: 11)),
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
                Text(_fecha(semana.inicio),
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

String _fecha(DateTime fecha) => '${fecha.day.toString().padLeft(2, '0')}/'
  '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

Widget _dato(String etiqueta, String valor) => Column(
  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
  children: [
    Text(valor, style: const TextStyle(fontSize: 15, color: EcoColors.forest,
      fontWeight: FontWeight.w900)),
    Text(etiqueta, style: const TextStyle(fontSize: 11, color: EcoColors.muted)),
  ],
);

Widget _lineaDetalle(String etiqueta, String valor) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 140, child: Text(etiqueta,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
    const SizedBox(width: 5),
    Expanded(child: Text(valor,
      style: const TextStyle(fontSize: 11.5, color: EcoColors.muted))),
  ]),
);

Widget _tarjetaReincidencia(ReincidenciaEco r) => EcoPanel(
  padding: const EdgeInsets.all(13),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.repeat_rounded, color: EcoColors.green, size: 19),
      const SizedBox(width: 7),
      Expanded(child: Text(r.nuevoReporte.titulo,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
    ]),
    const SizedBox(height: 7),
    Text('Reporte anterior: ${r.incidenciaAnterior.titulo}',
      style: const TextStyle(fontSize: 12, color: EcoColors.muted)),
    const SizedBox(height: 6),
    Wrap(spacing: 12, runSpacing: 5, children: [
      Text('${r.nuevoReporte.tipo} · ${r.nuevoReporte.comuna}',
        style: const TextStyle(fontSize: 11.5)),
      Text('Separación: ${r.distanciaMetros.round()} m',
        style: const TextStyle(fontSize: 11.5)),
      Text('Reaparición: ${r.diasDesdeCierre} días',
        style: const TextStyle(fontSize: 11.5)),
      Text('Prioridad actual: ${r.nuevoReporte.prioridad}/100',
        style: const TextStyle(fontSize: 11.5)),
    ]),
    const SizedBox(height: 5),
    Text('Cierre anterior: ${_fecha(r.incidenciaAnterior.cerradoEn!)} '
      '· reporte nuevo: ${_fecha(r.nuevoReporte.creadoEn)}',
      style: const TextStyle(fontSize: 11, color: EcoColors.muted)),
  ]),
);

String _prioridadTexto(int valor) => valor >= 75 ? 'Alta'
    : valor >= 45 ? 'Media' : 'Baja';

Widget _tarjetaAlerta(AlertaEco alerta) {
  final vencida = alerta.vencida;
  final reporte = alerta.reporte;
  final retraso = -alerta.horasRestantes / 24;
  return EcoPanel(padding: const EdgeInsets.all(13), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(vencida ? Icons.error_outline : Icons.access_time_rounded,
          color: vencida ? Colors.red.shade700 : EcoColors.orange, size: 20),
        const SizedBox(width: 7),
        Expanded(child: Text(reporte.titulo,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
      ]),
      const SizedBox(height: 6),
      Text(vencida
        ? 'Plazo superado hace ${retraso.toStringAsFixed(1)} días'
        : 'Quedan ${alerta.horasRestantes} horas para el plazo',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: vencida ? Colors.red.shade700 : EcoColors.orange)),
      const SizedBox(height: 5),
      Wrap(spacing: 12, runSpacing: 5, children: [
        Text('${reporte.tipo} · ${reporte.comuna}',
          style: const TextStyle(fontSize: 11.5)),
        Text('Prioridad: ${_prioridadTexto(reporte.prioridad)} '
          '(${reporte.prioridad}/100)',
          style: const TextStyle(fontSize: 11.5)),
        Text('Estado: ${estadoNombre(reporte.estado)}',
          style: const TextStyle(fontSize: 11.5)),
        Text('Plazo estimado: ${alerta.plazoDias} días',
          style: const TextStyle(fontSize: 11.5)),
      ]),
      const SizedBox(height: 5),
      Text('Registrada: ${_fecha(reporte.creadoEn)} '
        '· antigüedad: ${alerta.diasTranscurridos} días',
        style: const TextStyle(fontSize: 11, color: EcoColors.muted)),
    ]),
  );
}

/// Pantallas completas con listas perezosas para evitar construir 180 tarjetas
/// dentro de EcoImpacto. Solo se abren desde la vista administrativa.
class _TodasReincidencias extends StatefulWidget {
  final List<ReincidenciaEco> resultados;
  const _TodasReincidencias({required this.resultados});
  @override
  State<_TodasReincidencias> createState() => _TodasReincidenciasState();
}

class _TodasReincidenciasState extends State<_TodasReincidencias> {
  String filtro = 'Todas';
  @override
  Widget build(BuildContext context) {
    final datos = widget.resultados.where((r) => switch (filtro) {
      'Hasta 50 m' => r.distanciaMetros <= 50,
      '51–100 m' => r.distanciaMetros > 50 && r.distanciaMetros <= 100,
      '101–150 m' => r.distanciaMetros > 100,
      _ => true,
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Todas las reincidencias')),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: datos.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${datos.length} de ${widget.resultados.length} coincidencias',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: EcoColors.forest)),
              const SizedBox(height: 7),
              const Text('Filtra por la distancia entre el reporte nuevo y el anterior. '
                'La coincidencia necesita verificación en terreno.',
                style: TextStyle(fontSize: 12, color: EcoColors.muted)),
              const SizedBox(height: 13),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final opcion in ['Todas', 'Hasta 50 m', '51–100 m', '101–150 m'])
                  ChoiceChip(label: Text(opcion), selected: opcion == filtro,
                    onSelected: (_) => setState(() => filtro = opcion)),
              ]),
              const SizedBox(height: 14),
            ]);
          }
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: _tarjetaReincidencia(datos[index - 1]));
        },
      ),
    );
  }
}

class _TodasAlertas extends StatefulWidget {
  final List<AlertaEco> alertas;
  const _TodasAlertas({required this.alertas});
  @override
  State<_TodasAlertas> createState() => _TodasAlertasState();
}

class _TodasAlertasState extends State<_TodasAlertas> {
  String filtro = 'Todas';
  @override
  Widget build(BuildContext context) {
    final datos = widget.alertas.where((a) => switch (filtro) {
      'Vencidas' => a.vencida,
      'Próximas' => !a.vencida,
      'Alta' => a.reporte.prioridad >= 75,
      'Media' => a.reporte.prioridad >= 45 && a.reporte.prioridad < 75,
      'Baja' => a.reporte.prioridad < 45,
      _ => true,
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Todas las alertas')),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: datos.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${datos.length} de ${widget.alertas.length} alertas',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: EcoColors.forest)),
              const SizedBox(height: 7),
              const Text('Ordenadas desde el plazo más vencido. '
                'Filtra por situación o por prioridad.',
                style: TextStyle(fontSize: 12, color: EcoColors.muted)),
              const SizedBox(height: 13),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final opcion in ['Todas', 'Vencidas', 'Próximas', 'Alta', 'Media', 'Baja'])
                  ChoiceChip(label: Text(opcion), selected: opcion == filtro,
                    onSelected: (_) => setState(() => filtro = opcion)),
              ]),
              const SizedBox(height: 14),
            ]);
          }
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: _tarjetaAlerta(datos[index - 1]));
        },
      ),
    );
  }
}
