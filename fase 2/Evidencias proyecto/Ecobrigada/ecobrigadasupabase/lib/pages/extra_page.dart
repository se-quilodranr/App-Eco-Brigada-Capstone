import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';
import '../widgets/common.dart';

class ExtraPage extends StatelessWidget {
  final EcoStore store;
  final String opcion;
  const ExtraPage({super.key, required this.store, required this.opcion});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(switch (opcion) {
      'guias' => 'Guías ambientales',
      'logros' => 'EcoLogros',
      _ => 'Sobre EcoBrigada',
    })),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        if (opcion == 'guias') ...[
          const EcoSection(title: 'Aprendamos a cuidar el planeta',
            subtitle: 'Material educativo de referencia'),
          const _Guia(icono: Icons.recycling_outlined, titulo: 'Separación de residuos',
            texto: 'Identifica papel, cartón, vidrio, metal y plásticos. Consulta qué materiales acepta tu centro de reciclaje antes de llevarlos.'),
          const _Guia(icono: Icons.cleaning_services_outlined, titulo: 'Limpiezas seguras',
            texto: 'Utiliza guantes, evita manipular objetos cortantes o residuos peligrosos y coordina las actividades con responsables.'),
          const _Guia(icono: Icons.public_outlined, titulo: 'Reportar responsablemente',
            texto: 'Agrega una descripción verificable, una ubicación aproximada y evita publicar información privada de terceros.'),
        ] else if (opcion == 'logros') ...[
          const EcoSection(title: 'Mis EcoLogros',
            subtitle: 'Reconocimientos orientativos en esta versión'),
          _Logro(icono: Icons.emoji_events_rounded, titulo: 'Primer paso',
            descripcion: 'Registrar al menos una incidencia',
            logrado: store.reportes.any((r) => r.creadorUid == store.uid)),
          _Logro(icono: Icons.groups_rounded, titulo: 'Trabajo colaborativo',
            descripcion: 'Liderar una brigada ambiental',
            logrado: store.brigadas.any((b) => b.liderUid == store.uid)),
          const EcoPanel(child: Text('Las recompensas verificadas y el sistema de puntos están planificados para una versión posterior.')),
        ] else ...[
          const EcoSection(title: 'EcoBrigada 2.0',
            subtitle: 'Sistema de gestión y monitoreo ambiental comunitario'),
          const EcoPanel(child: Text('La aplicación centraliza reportes, permite priorizar incidencias y asignar brigadas, gestiona sus estados y muestra indicadores de resolución. EcoRadar y EcoMatch son algoritmos basados en reglas, no Machine Learning.')),
          const SizedBox(height: 16),
          const EcoPanel(child: Text('Supabase centraliza la autenticación, la base de datos PostgreSQL, el almacenamiento privado de fotografías y las notificaciones. Los permisos reales se controlan en PostgreSQL con políticas RLS.')),
        ],
      ]))),
  );
}

class _Guia extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const _Guia({required this.icono, required this.titulo, required this.texto});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: EcoPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: EcoColors.mint,
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icono, color: EcoColors.green)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(texto, style: const TextStyle(color: EcoColors.muted,
              height: 1.5)),
          ])),
      ])),
  );
}

class _Logro extends StatelessWidget {
  final IconData icono;
  final String titulo, descripcion;
  final bool logrado;
  const _Logro({required this.icono, required this.titulo,
    required this.descripcion, required this.logrado});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: EcoPanel(child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: EcoColors.mint,
        child: Icon(icono, color: EcoColors.green)),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(descripcion),
      trailing: Icon(logrado ? Icons.check_circle : Icons.lock_outline,
        color: logrado ? EcoColors.green : EcoColors.muted),
    )),
  );
}
