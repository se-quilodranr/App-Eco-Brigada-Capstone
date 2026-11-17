import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api.dart';

class ChatPage extends StatefulWidget {
  final String brigadaId;
  final String nombreBrigada;
  const ChatPage({
    super.key,
    required this.brigadaId,
    required this.nombreBrigada,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final mensaje = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> mensajes;
  Map<String, String> nombres = {};
  bool enviando = false;
  @override
  void initState() {
    super.initState();
    mensajes = Api.chat(widget.brigadaId);
    cargarNombres();
  }

  Future<void> cargarNombres() async {
    try {
      final rows = await Api.miembros(widget.brigadaId);
      if (!mounted) return;
      setState(
        () => nombres = {
          for (final r in rows)
            r['usuario_id'].toString():
                (r['perfiles'] as Map?)?['nombre']?.toString() ?? 'Brigadista',
        },
      );
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> enviar() async {
    if (mensaje.text.trim().isEmpty || enviando) return;
    setState(() => enviando = true);
    try {
      await Api.enviarMensaje(widget.brigadaId, mensaje.text);
      if (mounted) mensaje.clear();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  void dispose() {
    mensaje.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Chat · ${widget.nombreBrigada}')),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: mensajes,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('No puedes leer el chat: ${snap.error}'),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = snap.data!;
              if (lista.isEmpty) {
                return const Center(
                  child: Text('No hay mensajes. ¡Inicia la conversación!'),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: lista.length,
                itemBuilder: (ctx, index) {
                  final m = lista[lista.length - 1 - index];
                  final propio = m['autor_id'] == Api.db.auth.currentUser?.id;
                  return Align(
                    alignment: propio
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Card(
                        color: propio ? const Color(0xFFD6F5E3) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombres[m['autor_id'].toString()] ??
                                    'Brigadista',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF21865A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m['texto'].toString()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: mensaje,
                    maxLength: 2000,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => enviar(),
                  ),
                ),
                IconButton(
                  onPressed: enviando ? null : enviar,
                  icon: const Icon(Icons.send, color: Color(0xFF21865A)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
