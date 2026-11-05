
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatBrigadaPage extends StatefulWidget {
  final String brigadaId;
  final String nombreBrigada;

  const ChatBrigadaPage({
    super.key,
    required this.brigadaId,
    required this.nombreBrigada,
  });

  @override
  State<ChatBrigadaPage> createState() => _ChatBrigadaPageState();
}

class _ChatBrigadaPageState extends State<ChatBrigadaPage> {
  final mensajeController = TextEditingController();
  bool enviando = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      mensajesStream;

  @override
  void initState() {
    super.initState();

    mensajesStream = FirebaseFirestore.instance
        .collection('brigadas')
        .doc(widget.brigadaId)
        .collection('mensajes')
        .orderBy('fechaEnvio', descending: true)
        .limit(100)
        .snapshots();
  }

  // Asignar un color estable según el UID
  Color colorUsuario(String uid) {
    const colores = [
      Colors.blue,
      Colors.green,
      Colors.deepPurple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    final numero = uid.codeUnits.fold<int>(
      0,
      (total, codigo) => (total * 31 + codigo) & 0x7fffffff,
    );

    return colores[numero % colores.length];
  }

  // ENVIAR MENSAJES
  Future<void> enviarMensaje() async {
    final texto = mensajeController.text.trim();
    final usuario = FirebaseAuth.instance.currentUser;

    if (texto.isEmpty || usuario == null || enviando) {
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      String nombre = usuario.displayName?.trim() ?? '';

      if (nombre.isEmpty) {
        nombre = usuario.email?.split('@').first ?? 'Usuario';
      }

      await FirebaseFirestore.instance
          .collection('brigadas')
          .doc(widget.brigadaId)
          .collection('mensajes')
          .add({
            'texto': texto,
            'uid': usuario.uid,
            'nombre': nombre,
            'fechaEnvio': FieldValue.serverTimestamp(),
          });

      mensajeController.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al enviar: ${e.message ?? e.code}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreBrigada),
      ),

      body: Column(
        children: [
          // LISTA DE MENSAJES
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: mensajesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar mensajes:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final mensajes = snapshot.data!.docs;

                if (mensajes.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay mensajes'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final datos = mensajes[index].data();

                    final texto = datos['texto'] as String? ?? '';
                    final nombre = datos['nombre'] as String? ?? '';
                    final uid = datos['uid'] as String? ?? '';

                    final esMio = uid == usuarioActual?.uid;

                    return Align(
                      alignment: esMio
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.sizeOf(context).width * 0.78,
                        ),

                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 5,
                          ),
                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: esMio
                                ? const Color(0xFFDDF3E4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorUsuario(uid),
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(texto),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // CAMPO PARA ESCRIBIR
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: mensajeController,
                      maxLength: 500,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        enviarMensaje();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton.filled(
                    onPressed: enviando ? null : enviarMensaje,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
