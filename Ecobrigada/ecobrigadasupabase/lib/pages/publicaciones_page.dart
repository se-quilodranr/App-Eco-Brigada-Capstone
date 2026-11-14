import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/api.dart';

class PublicacionesPage extends StatefulWidget {
  const PublicacionesPage({super.key});
  @override
  State<PublicacionesPage> createState() => _PublicacionesPageState();
}

class _PublicacionesPageState extends State<PublicacionesPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    actualizar();
  }

  void actualizar() => setState(() => future = Api.publicaciones());

  Future<void> crear() async {
    if (!await asegurarSesion(context)) return;
    if (!mounted) return;
    final nueva = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CrearPublicacionPage()),
    );
    if (nueva == true) actualizar();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ideas para reciclar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: actualizar,
              icon: const Icon(Icons.refresh),
            ),
            FilledButton.icon(
              onPressed: crear,
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (ctx, snap) {
            if (!snap.hasData && !snap.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error al cargar: ${snap.error}'));
            }
            final posts = snap.data!;
            if (posts.isEmpty) {
              return const Center(
                child: Text('Aún no hay guías de reciclaje.'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                actualizar();
                await future;
              },
              child: LayoutBuilder(
                builder: (ctx, c) => GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.maxWidth >= 1000
                        ? 3
                        : c.maxWidth >= 620
                        ? 2
                        : 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 320,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (ctx, i) {
                    final p = posts[i];
                    final fotos = List<Map<String, dynamic>>.from(
                      p['publicacion_fotos'] ?? [],
                    );
                    fotos.sort(
                      (a, b) => (a['posicion'] as num).compareTo(
                        b['posicion'] as num,
                      ),
                    );
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => PublicacionDetallePage(post: p),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 165,
                              child: fotos.isEmpty
                                  ? const ColoredBox(
                                      color: Color(0xFFD9EEDF),
                                      child: Center(
                                        child: Icon(
                                          Icons.recycling,
                                          size: 64,
                                          color: Color(0xFF21865A),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      Api.urlFoto(
                                        fotos.first['ruta_storage'].toString(),
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, e, s) => const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 50,
                                        ),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['titulo'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(ctx).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p['descripcion']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Por ${(p['perfiles'] as Map?)?['nombre'] ?? 'Brigadista'}',
                                  ),
                                  Text(
                                    '♥ ${(p['publicacion_likes'] as List?)?.length ?? 0}',
                                    style: const TextStyle(
                                      color: Color(0xFF21865A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class CrearPublicacionPage extends StatefulWidget {
  const CrearPublicacionPage({super.key});
  @override
  State<CrearPublicacionPage> createState() => _CrearPublicacionPageState();
}

class _CrearPublicacionPageState extends State<CrearPublicacionPage> {
  final titulo = TextEditingController();
  final descripcion = TextEditingController();
  final materiales = TextEditingController();
  final pasos = TextEditingController();
  List<XFile> fotos = [];
  bool guardando = false;
  @override
  void dispose() {
    titulo.dispose();
    descripcion.dispose();
    materiales.dispose();
    pasos.dispose();
    super.dispose();
  }

  Future<void> elegirFotos() async {
    try {
      final lista = await ImagePicker().pickMultiImage(
        maxWidth: 1400,
        imageQuality: 72,
      );
      if (lista.length > 3) {
        if (mounted) mostrarError(context, 'Selecciona máximo 3 fotografías.');
        return;
      }
      if (mounted) setState(() => fotos = lista);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> publicar() async {
    final lista = pasos.text
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (titulo.text.trim().length < 3 || lista.isEmpty) {
      mostrarError(context, 'Escribe el título y los pasos (uno por línea).');
      return;
    }
    if (guardando) return;
    setState(() => guardando = true);
    try {
      await Api.crearPublicacion(
        titulo: titulo.text,
        descripcion: descripcion.text,
        materiales: materiales.text,
        pasos: lista,
        fotos: fotos,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva guía de reciclaje')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Comparte cómo reutilizar materiales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: titulo,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Título de la guía',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcion,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: materiales,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Materiales necesarios',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pasos,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Pasos (uno por línea)',
                hintText: 'Lava la botella\nCorta la parte superior\nDecora el recipiente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: elegirFotos,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Seleccionar fotos (${fotos.length}/3)'),
            ),
            const Text(
              'Se comprimen al elegirlas. Máximo 5 MB por foto.',
              style: TextStyle(color: Colors.grey),
            ),
            if (fotos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(fotos.map((f) => f.name).join(' · ')),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: guardando ? null : publicar,
              icon: const Icon(Icons.cloud_upload),
              label: Text(guardando ? 'Guardando...' : 'Publicar guía'),
            ),
            if (guardando)
              const Padding(
                padding: EdgeInsets.all(14),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
  );
}

class PublicacionDetallePage extends StatefulWidget {
  final Map<String, dynamic> post;
  const PublicacionDetallePage({super.key, required this.post});
  @override
  State<PublicacionDetallePage> createState() => _PublicacionDetallePageState();
}

class _PublicacionDetallePageState extends State<PublicacionDetallePage> {
  late final List<Map<String, dynamic>> fotos;
  late final List<Map<String, dynamic>> pasos;
  late int cantidadLikes;
  late bool meGusta;
  int fotoActual = 0;
  final textoComentario = TextEditingController();
  late Future<List<Map<String, dynamic>>> comentarios;
  @override
  void initState() {
    super.initState();
    fotos = List<Map<String, dynamic>>.from(
      widget.post['publicacion_fotos'] ?? [],
    );
    fotos.sort(
      (a, b) => (a['posicion'] as num).compareTo(b['posicion'] as num),
    );
    pasos = List<Map<String, dynamic>>.from(
      widget.post['publicacion_pasos'] ?? [],
    );
    pasos.sort((a, b) => (a['numero'] as num).compareTo(b['numero'] as num));
    final likes = List<Map<String, dynamic>>.from(
      widget.post['publicacion_likes'] ?? [],
    );
    cantidadLikes = likes.length;
    meGusta = likes.any((p) => p['usuario_id'] == Api.db.auth.currentUser?.id);
    recargarComentarios();
  }

  void recargarComentarios() =>
      comentarios = Api.comentarios(widget.post['id'].toString());
  @override
  void dispose() {
    textoComentario.dispose();
    super.dispose();
  }

  Future<void> like() async {
    if (!await asegurarSesion(context)) return;
    try {
      await Api.alternarLike(widget.post['id'].toString());
      if (mounted) {
        setState(() {
          meGusta = !meGusta;
          cantidadLikes += meGusta ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> comentar() async {
    if (!await asegurarSesion(context)) return;
    try {
      await Api.comentar(widget.post['id'].toString(), textoComentario.text);
      textoComentario.clear();
      if (mounted) setState(recargarComentarios);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> reportar() async {
    if (!await asegurarSesion(context)) return;
    if (!mounted) return;
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reportar publicación'),
        children: [
          for (final s in [
            'Contenido inapropiado',
            'Spam',
            'Información falsa',
            'Otro motivo',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text(s),
            ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      await Api.reportar(widget.post['id'].toString(), motivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado para revisión.')),
        );
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final ancho = MediaQuery.sizeOf(context).width;
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotos.isNotEmpty)
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  Api.urlFoto(fotos[fotoActual]['ruta_storage'].toString()),
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
              if (fotos.length > 1) ...[
                Positioned(
                  left: 4,
                  top: 75,
                  child: IconButton.filledTonal(
                    onPressed: () => setState(
                      () => fotoActual =
                          (fotoActual - 1 + fotos.length) % fotos.length,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 75,
                  child: IconButton.filledTonal(
                    onPressed: () => setState(
                      () => fotoActual = (fotoActual + 1) % fotos.length,
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 14),
        Text(
          p['titulo'].toString(),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Por ${(p['perfiles'] as Map?)?['nombre'] ?? 'Brigadista'}'),
        const SizedBox(height: 8),
        Text(p['descripcion']?.toString() ?? ''),
        const SizedBox(height: 14),
        Text('Materiales', style: Theme.of(context).textTheme.titleMedium),
        Text(p['materiales']?.toString() ?? ''),
        const SizedBox(height: 14),
        Text('Paso a paso', style: Theme.of(context).textTheme.titleMedium),
        for (final paso in pasos)
          ListTile(
            leading: CircleAvatar(child: Text('${paso['numero']}')),
            title: Text(paso['texto'].toString()),
          ),
        Row(
          children: [
            IconButton(
              onPressed: like,
              icon: Icon(
                meGusta ? Icons.favorite : Icons.favorite_border,
                color: Colors.red,
              ),
            ),
            Text('$cantidadLikes me gusta'),
            const Spacer(),
            TextButton.icon(
              onPressed: reportar,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Reportar'),
            ),
          ],
        ),
      ],
    );
    final lateral = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Comentarios', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: comentarios,
          builder: (ctx, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aún no hay comentarios.'),
              );
            }
            return Column(
              children: [
                for (final c in snap.data!)
                  Card(
                    child: ListTile(
                      title: Text(
                        (c['perfiles'] as Map?)?['nombre']?.toString() ??
                            'Brigadista',
                      ),
                      subtitle: Text(c['texto'].toString()),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: textoComentario,
          maxLength: 1000,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Escribe un comentario',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: comentar,
          icon: const Icon(Icons.send),
          label: const Text('Comentar'),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Guía de reciclaje')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ancho >= 760
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: contenido),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: lateral),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [contenido, const Divider(height: 32), lateral],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
