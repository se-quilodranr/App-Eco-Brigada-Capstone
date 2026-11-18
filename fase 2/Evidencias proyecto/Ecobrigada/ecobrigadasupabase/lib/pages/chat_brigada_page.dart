import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/models.dart';
import '../core/store.dart';

/// Chat en tiempo real con Supabase, protegido con RLS.
class ChatBrigadaPage extends StatefulWidget {
  final EcoStore store;
  final String brigadaId;
  const ChatBrigadaPage({super.key, required this.store,
    required this.brigadaId});

  @override
  State<ChatBrigadaPage> createState() => _ChatBrigadaPageState();
}

class _ChatBrigadaPageState extends State<ChatBrigadaPage> {
  final campo = TextEditingController();
  late final Stream<List<MensajeBrigada>>? streamMensajes;
  bool enviando = false;

  @override
  void initState() {
    super.initState();
    streamMensajes = widget.store.puedeChatear(widget.brigadaId)
        ? widget.store.escucharMensajes(widget.brigadaId)
        : null;
  }

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  Future<void> enviar() async {
    final texto = campo.text.trim();
    if (texto.isEmpty || enviando) return;
    setState(() => enviando = true);
    try {
      await widget.store.enviarMensaje(widget.brigadaId, texto);
      if (mounted) campo.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final s = widget.store;
      final nombres = s.brigadas.where((b) => b.id == widget.brigadaId);
      final nombre = nombres.isEmpty ? 'Brigada' : nombres.first.nombre;
      final autorizado = s.puedeChatear(widget.brigadaId);
      return Scaffold(
        appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Chat · $nombre', maxLines: 1,
            overflow: TextOverflow.ellipsis),
            const Text('Mensajería privada en tiempo real · Supabase',
              style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.normal, color: EcoColors.muted)),
          ])),
        body: !autorizado
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, size: 48, color: EcoColors.muted),
                SizedBox(height: 14),
                Text('Chat privado de la brigada',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Para participar debes ser integrante aprobado, líder de esta brigada o administrador.',
                  textAlign: TextAlign.center),
              ])))
          : Column(children: [
              Expanded(child: StreamBuilder<List<MensajeBrigada>>(
                    stream: streamMensajes,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text('No se pudo leer el chat: ${snapshot.error}. '
                            'Comprueba membresía y políticas RLS.',
                            textAlign: TextAlign.center)));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _listaMensajes(snapshot.data!, s.uid);
                    })),
              const Divider(height: 1),
              SafeArea(top: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: campo, maxLength: 1000,
                    minLines: 1, maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje al equipo…',
                      counterText: '', border: OutlineInputBorder()),
                    onSubmitted: (_) => enviar(),
                  )),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    onPressed: enviando ? null : enviar,
                    tooltip: 'Enviar mensaje',
                    icon: enviando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  ),
                ]))),
            ]),
      );
    },
  );

  Widget _listaMensajes(List<MensajeBrigada> mensajes, String uid) {
    if (mensajes.isEmpty) {
      return const Center(child: Text('Aún no hay mensajes. ¡Inicia la conversación!',
        style: TextStyle(color: EcoColors.muted)));
    }
    final ordenados = mensajes.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: ordenados.length,
      itemBuilder: (context, index) {
        final m = ordenados[index];
        final propio = uid == m.autorUid;
        final hora = '${m.fecha.day.toString().padLeft(2, '0')}/'
          '${m.fecha.month.toString().padLeft(2, '0')} '
          '${m.fecha.hour.toString().padLeft(2, '0')}:'
          '${m.fecha.minute.toString().padLeft(2, '0')}';
        return Align(
          alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: propio ? EcoColors.mint : Colors.white,
              border: Border.all(color: EcoColors.pale),
              borderRadius: BorderRadius.circular(15)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.autorNombre, style: const TextStyle(
                  color: EcoColors.forest, fontSize: 12,
                  fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                SelectableText(m.texto),
                const SizedBox(height: 6),
                Text(hora, style: const TextStyle(
                  fontSize: 10, color: EcoColors.muted)),
              ]),
          ),
        );
      },
    );
  }
}
