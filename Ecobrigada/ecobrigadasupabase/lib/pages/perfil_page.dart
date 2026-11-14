import 'package:flutter/material.dart';

import '../services/api.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<Map<String, dynamic>?> perfil;
  late Future<List<Map<String, dynamic>>> solicitudes;
  @override
  void initState() {
    super.initState();
    cargar();
  }

  void cargar() {
    perfil = Api.perfil();
    solicitudes = Api.misSolicitudes();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Mi perfil', style: Theme.of(context).textTheme.headlineSmall),
      FutureBuilder<Map<String, dynamic>?>(
        future: perfil,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          final p = snap.data!;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                radius: 30,
                child: Icon(Icons.person, size: 36),
              ),
              title: Text(p['nombre'].toString()),
              subtitle: Text(
                'Puntos: ${p['puntos']}\n${Api.db.auth.currentUser?.email ?? ''}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Mis solicitudes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: () => setState(cargar),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: solicitudes,
        builder: (ctx, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          if (snap.data!.isEmpty) {
            return const Text('Aún no has enviado solicitudes.');
          }
          return Column(
            children: [
              for (final s in snap.data!)
                Card(
                  child: ListTile(
                    leading: Icon(
                      s['estado'] == 'aceptada'
                          ? Icons.check_circle
                          : s['estado'] == 'rechazada'
                          ? Icons.cancel
                          : Icons.hourglass_empty,
                      color: s['estado'] == 'aceptada'
                          ? Colors.green
                          : s['estado'] == 'rechazada'
                          ? Colors.red
                          : Colors.orange,
                    ),
                    title: Text(
                      (s['brigadas'] as Map?)?['nombre']?.toString() ??
                          'Brigada',
                    ),
                    subtitle: Text(
                      'Estado: ${s['estado']}${s['actividad_id'] == null ? '' : ' · ${((s['actividades'] as Map?)?['titulo'] ?? 'Actividad')}'}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () async {
          await Api.salir();
          if (mounted) setState(cargar);
        },
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ],
  );
}
