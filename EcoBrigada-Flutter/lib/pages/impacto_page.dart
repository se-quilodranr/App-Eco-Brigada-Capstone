import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ImpactoPage extends StatelessWidget {
  const ImpactoPage({super.key});

  Widget _tarjeta(String titulo, int total, IconData icono, Color color) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icono, color: color),
          ),
          title: Text(titulo),
          trailing: Text('$total',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Impacto ambiental · EcoBrigada')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('puntos_mapa').limit(500).snapshots(),
          builder: (context, puntos) {
            if (puntos.hasError) {
              return Center(child: Text('No se pudieron consultar los puntos: ${puntos.error}'));
            }
            if (!puntos.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = puntos.data!.docs;
            int contar(String tipo) => docs.where((p) => p.data()['tipo'] == tipo).length;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('zonas_criticas').limit(150).snapshots(),
              builder: (context, zonas) {
                final nZonas = zonas.data?.docs.length ?? 0;
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text('Indicadores del mapa',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _tarjeta('Puntos sucios', contar('sucio'), Icons.delete_outline, Colors.orange),
                    _tarjeta('Puntos limpiados', contar('limpiado'), Icons.check_circle, Colors.purple),
                    _tarjeta('Puntos de reciclaje', contar('reciclaje'), Icons.recycling, Colors.green),
                    _tarjeta('Ubicaciones de brigadas', contar('brigada'), Icons.groups, Colors.blue),
                    _tarjeta('Zonas identificadas por DBSCAN', nZonas,
                        Icons.analytics_outlined, Colors.deepOrange),
                    const SizedBox(height: 18),
                    const Text('Muestra descriptiva, no impacto ambiental certificado.',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Esta pantalla resume como máximo 500 puntos y 150 zonas. '
                        'No debe interpretarse como el total histórico si se superan esos límites. '
                        'Para estadísticas globales se necesitan contadores agregados en el backend.'),
                    if (zonas.hasError)
                      Text('Error al leer zonas ML: ${zonas.error}',
                          style: const TextStyle(color: Colors.red)),
                  ],
                );
              },
            );
          },
        ),
      );
}
