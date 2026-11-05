import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_brigada_page.dart';

class BrigadasPage extends StatefulWidget {
  const BrigadasPage({super.key});

  @override
  State<BrigadasPage> createState() => _BrigadasPageState();
}

class _BrigadasPageState extends State<BrigadasPage> {
  String busqueda = '';
  final nombreController = TextEditingController();
  final comunaController = TextEditingController();
  final brigadasStream = FirebaseFirestore.instance
      .collection('brigadas')
      .snapshots();

  Future<void> unirseBrigada(String brigadaId) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('brigadas')
          .doc(brigadaId)
          .update({
            'participantes': FieldValue.arrayUnion([usuario.uid]),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te has unido a la brigada')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al ingresar: ${e.message ?? e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BUSCADOR
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o comuna',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (texto) {
              setState(() {
                busqueda = texto.toLowerCase().trim();
              });
            },
          ),
        ),

        // LISTADO DE BRIGADAS
        Expanded(
          child: StreamBuilder(
            stream: brigadasStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error Firestore: ${snapshot.error}');

                return Center(
                  child: Text(
                    'Error al cargar las brigadas:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final documentos = snapshot.data!.docs;

              if (documentos.isEmpty) {
                return const Center(child: Text('No hay brigadas creadas'));
              }

              final filtradas = documentos.where((documento) {
                final datos = documento.data();
                final nombre = (datos['nombre'] as String? ?? '').toLowerCase();
                final comuna = (datos['comuna'] as String? ?? '').toLowerCase();

                return nombre.contains(busqueda) || comuna.contains(busqueda);
              }).toList();

              if (filtradas.isEmpty) {
                return const Center(child: Text('No se encontraron brigadas'));
              }

              return ListView.builder(
                itemCount: filtradas.length,
                itemBuilder: (context, index) {
                  final datos = filtradas[index].data();
                  final participantes =
                      datos['participantes'] as List<dynamic>? ?? [];

                  final creadorUid = datos['creadorUid'] as String?;
                  final usuario = FirebaseAuth.instance.currentUser;

                  final yaEsMiembro =
                      usuario != null &&
                      (usuario.uid == creadorUid ||
                          participantes.contains(usuario.uid));

                  final cantidad = <String>{
                    if (creadorUid != null && creadorUid.isNotEmpty) creadorUid,
                    ...participantes.whereType<String>(),
                  }.length;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      minTileHeight: 100,
                      onTap: yaEsMiembro
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatBrigadaPage(
                                    brigadaId: filtradas[index].id,
                                    nombreBrigada: datos['nombre'] ?? '',
                                  ),
                                ),
                              );
                            }
                          : null,
                      leading: const Icon(Icons.groups),
                      title: Text(datos['nombre'] ?? ''),
                      subtitle: Text(datos['comuna'] ?? ''),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          yaEsMiembro
                              ? const Text('Ya eres miembro')
                              : ElevatedButton(
                                  onPressed: () {
                                    unirseBrigada(filtradas[index].id);
                                  },
                                  child: const Text('Unirse'),
                                ),
                          const SizedBox(height: 4),
                          Text('$cantidad participantes'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Crear brigada'),

                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la brigada',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextField(
                            controller: comunaController,
                            decoration: const InputDecoration(
                              labelText: 'Comuna',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),

                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancelar'),
                        ),

                        FilledButton(
                          onPressed: () async {
                            final nombre = nombreController.text.trim();
                            final comuna = comunaController.text.trim();

                            // 1. Validar los campos
                            if (nombre.isEmpty || comuna.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Debes completar todos los campos',
                                  ),
                                ),
                              );
                              return;
                            }

                            // 2. Obtener al usuario autenticado
                            final usuario = FirebaseAuth.instance.currentUser;

                            if (usuario == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Debes iniciar sesión'),
                                ),
                              );
                              return;
                            }

                            // 3. Guardar la brigada
                            try {
                              await FirebaseFirestore.instance
                                  .collection('brigadas')
                                  .add({
                                    'nombre': nombre,
                                    'comuna': comuna,
                                    'creadorUid': usuario.uid,
                                    'creadorNombre': usuario.displayName ?? '',
                                    'fechaCreacion':
                                        FieldValue.serverTimestamp(),
                                  });

                              if (!context.mounted) return;

                              // 4. Limpiar los campos
                              nombreController.clear();
                              comunaController.clear();

                              // 5. Cerrar el modal
                              Navigator.pop(context);

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Brigada creada correctamente'),
                                ),
                              );
                            } on FirebaseException catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al guardar: ${e.message ?? e.code}',
                                  ),
                                ),
                              );
                            }
                          },

                          child: const Text('Crear'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('crear brigada'),
            ),
          ),
        ),
      ],
    );
  }
}
