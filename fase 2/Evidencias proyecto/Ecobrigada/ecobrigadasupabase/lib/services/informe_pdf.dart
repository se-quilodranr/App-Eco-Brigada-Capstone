import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';

class InformePdf {
  static Future<void> exportar(List<Reporte> reportes,
    List<Brigada> brigadas,List<Jornada> jornadas) async {
    final doc=pw.Document();
    final resueltos=reportes.where((r)=>r.estado=='cerrado').length;
    final pendientes=reportes.where((r)=>r.abierto).length;
    final fecha=DateTime.now();
    final detalle=[...reportes]..sort((a,b)=>b.creadoEn.compareTo(a.creadoEn));
    final fotos=<pw.Widget>[];
    // Selección acotada de evidencias con autorización desde Storage privado.
    try {
      final db=Supabase.instance.client;
      final data=await db.from('fotos_incidencia').select('fase,reporte_id,storage_path')
          .order('creado_en',ascending:false).limit(6);
      for(final item in data){
        try{
          final bytes=await db.storage.from('eco-evidencias')
              .download('${item['storage_path']}');
          fotos.add(pw.Container(margin:const pw.EdgeInsets.only(bottom:10),
            child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
              pw.Text('${item['fase']=='inicial'?'Antes':'Después'} - Incidencia: ${item['reporte_id']}',
                style:const pw.TextStyle(fontSize:8)),
              pw.SizedBox(height:5),
              pw.Image(pw.MemoryImage(bytes),height:110,fit:pw.BoxFit.contain),
            ])));
        }catch(_){ /* Evidencia inaccesible: omitir, nunca suplantar. */ }
      }
    }catch(_){ /* El informe estadístico sigue disponible sin fotos. */ }

    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,
      margin:const pw.EdgeInsets.all(32),
      build:(ctx)=>[
        pw.Text('ECOBRIGADA | INFORME AMBIENTAL',style:pw.TextStyle(fontSize:19,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:8),
        pw.Text('Generado: ${fecha.day}/${fecha.month}/${fecha.year}'),
        pw.Divider(),
        pw.Text('Reporte de gestion',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold)),
        pw.Text('Incidencias: ${reportes.length} | Resueltas: $resueltos | Activas: $pendientes'),
        pw.Text('Brigadas: ${brigadas.length} | Jornadas: ${jornadas.length}'),
        pw.SizedBox(height:18),
        pw.Text('Incidencias registradas',style:pw.TextStyle(fontSize:13,fontWeight:pw.FontWeight.bold)),
        pw.Table.fromTextArray(headers:['Incidencia','Comuna','Estado','Prioridad'],
          data:detalle.take(300).map((r)=>[r.titulo,r.comuna,estadoNombre(r.estado),'${r.prioridad}/100']).toList(),
          headerStyle:pw.TextStyle(fontWeight:pw.FontWeight.bold),
          cellStyle:const pw.TextStyle(fontSize:8)),
        pw.SizedBox(height:15),
        if(fotos.isNotEmpty) ...[
          pw.SizedBox(height:20),
          pw.Text('Evidencias fotográficas recientes (muestra)',
            style:pw.TextStyle(fontSize:13,fontWeight:pw.FontWeight.bold)),
          ...fotos,
        ],
        pw.Text('Fuente: incidencias registradas en EcoBrigada. Los indicadores no constituyen una medicion directa de contaminacion.',
          style:const pw.TextStyle(fontSize:9)),
      ]));
    await Printing.layoutPdf(onLayout:(format)=>doc.save(),name:'EcoBrigada_Informe.pdf');
  }
}
