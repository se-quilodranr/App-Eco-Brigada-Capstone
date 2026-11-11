import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Se usan los mismos colores del main.dart de EcoBrigada.
const Color _verde = Color(0xFF21865A);
const Color _fondo = Color(0xFFF4F8F4);
const int _maxFotos = 8;
const int _maxPasos = 12;
const int _maxBytesFoto = 5 * 1024 * 1024;

String _autor(User user) {
  final nombre = user.displayName?.trim() ?? '';
  if (nombre.isNotEmpty) {
    return nombre.length > 100 ? nombre.substring(0, 100) : nombre;
  }
  final correo = user.email?.trim() ?? '';
  return correo.isEmpty ? 'EcoBrigadista' : correo.split('@').first;
}

void _mensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensaje)),
  );
}

String _errorAmigable(Object e) {
  if (e is FirebaseException) {
    if (e.code == 'permission-denied' || e.code == 'unauthorized') {
      return 'Firebase rechazó la operación. Revisa las reglas de Firestore o Storage.';
    }
    if (e.code == 'canceled') return 'La operación fue cancelada.';
    if (e.code == 'quota-exceeded') {
      return 'Se alcanzó un límite de Firebase Storage. Revisa el plan y su consumo.';
    }
    return 'Error de Firebase (${e.code}): ${e.message ?? 'intenta nuevamente'}';
  }
  return 'No se completó la operación. Revisa tu conexión e inténtalo otra vez.';
}

/// Feed público. Solo iniciar sesión para publicar, comentar, dar like o reportar.
class PublicacionesPage extends StatefulWidget {
  const PublicacionesPage({super.key, required this.onSolicitarLogin});

  /// El HomePage existente abre su pantalla AuthPage y devuelve si ingresó.
  final Future<bool> Function() onSolicitarLogin;

  @override
  State<PublicacionesPage> createState() => _PublicacionesPageState();
}

class _PublicacionesPageState extends State<PublicacionesPage> {
  Future<bool> _autenticado() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    final ingreso = await widget.onSolicitarLogin();
    if (!mounted) return false;
    if (!ingreso || FirebaseAuth.instance.currentUser == null) {
      _mensaje(context, 'Necesitas iniciar sesión para realizar esa acción.');
      return false;
    }
    setState(() {});
    return true;
  }

  Future<void> _crearPublicacion() async {
    if (!await _autenticado() || !mounted) return;
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _CrearPublicacionPage()),
    );
    if (creada == true && mounted) {
      _mensaje(context, '¡Tu guía de reciclaje fue publicada! 🌱');
    }
  }

  void _abrirPublicacion(String id, Map<String, dynamic> publicacion) {
    showDialog<void>(
      context: context,
      builder: (_) => _DetallePublicacionDialog(
        id: id,
        publicacion: publicacion,
        solicitarLogin: _autenticado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: _fondo,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ideas para reciclar',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 3),
                  Text('Comparte tus manuales e inspira a la comunidad.'),
                ],
              ),
              FilledButton.icon(
                onPressed: _crearPublicacion,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Crear publicación'),
                style: FilledButton.styleFrom(backgroundColor: _verde),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('publicaciones')
                .orderBy('creadoEn', descending: true)
                .limit(60)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _EstadoInformativo(
                  icono: Icons.error_outline,
                  titulo: 'No pudimos cargar las publicaciones',
                  detalle: _errorAmigable(snapshot.error!),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final documentos = snapshot.data!.docs;
              if (documentos.isEmpty) {
                return const _EstadoInformativo(
                  icono: Icons.auto_stories_outlined,
                  titulo: 'Aún no hay guías',
                  detalle: '¡Sé la primera persona en publicar una idea!',
                );
              }
              return LayoutBuilder(
                builder: (context, restricciones) {
                  // Tres columnas en PC; dos en tablet y una en teléfono.
                  final ancho = restricciones.maxWidth;
                  final columnas = ancho >= 980 ? 3 : ancho >= 630 ? 2 : 1;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 330,
                    ),
                    itemCount: documentos.length,
                    itemBuilder: (context, indice) {
                      final doc = documentos[indice];
                      return _TarjetaPublicacion(
                        id: doc.id,
                        data: doc.data(),
                        onAbrir: () => _abrirPublicacion(doc.id, doc.data()),
                        solicitarLogin: _autenticado,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EstadoInformativo extends StatelessWidget {
  const _EstadoInformativo({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });
  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 58, color: _verde),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

List<String> _fotos(Map<String, dynamic> datos) {
  final valor = datos['fotos'];
  if (valor is! List) return [];
  return valor.whereType<String>().toList();
}

List<String> _pasos(Map<String, dynamic> datos) {
  final valor = datos['pasos'];
  if (valor is! List) return [];
  return valor.whereType<String>().toList();
}

class _TarjetaPublicacion extends StatelessWidget {
  const _TarjetaPublicacion({
    required this.id,
    required this.data,
    required this.onAbrir,
    required this.solicitarLogin,
  });
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onAbrir;
  final Future<bool> Function() solicitarLogin;

  @override
  Widget build(BuildContext context) {
    final imagenes = _fotos(data);
    final titulo = data['titulo']?.toString() ?? 'Guía de reciclaje';
    final descripcion = data['descripcion']?.toString() ?? '';
    final nombre = data['autorNombre']?.toString() ?? 'EcoBrigadista';
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onAbrir,
            child: SizedBox(
              height: 162,
              child: imagenes.isEmpty
                  ? const ColoredBox(
                      color: _fondo,
                      child: Center(
                        child: Icon(Icons.recycling, color: _verde, size: 58),
                      ),
                    )
                  : Image.network(
                      imagenes.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: _fondo,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Text(
                    'Por $nombre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Row(
                    children: [
                      _BotonLike(id: id, solicitarLogin: solicitarLogin),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onAbrir,
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: const Text('Ver guía'),
                      ),
                    ],
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

class _BotonLike extends StatefulWidget {
  const _BotonLike({required this.id, required this.solicitarLogin});
  final String id;
  final Future<bool> Function() solicitarLogin;

  @override
  State<_BotonLike> createState() => _BotonLikeState();
}

class _BotonLikeState extends State<_BotonLike> {
  bool _ocupado = false;

  Future<void> _alternar() async {
    if (_ocupado) return;
    if (!await widget.solicitarLogin() || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _ocupado = true);
    try {
      final doc = FirebaseFirestore.instance
          .collection('publicaciones')
          .doc(widget.id)
          .collection('likes')
          .doc(user.uid);
      final actual = await doc.get();
      if (actual.exists) {
        await doc.delete();
      } else {
        await doc.set({
          'uid': user.uid,
          'creadoEn': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) _mensaje(context, _errorAmigable(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publicaciones')
          .doc(widget.id)
          .collection('likes')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final leGusta = uid != null && docs.any((doc) => doc.id == uid);
        return TextButton.icon(
          onPressed: _ocupado ? null : _alternar,
          icon: Icon(
            leGusta ? Icons.favorite : Icons.favorite_border,
            color: leGusta ? Colors.redAccent : _verde,
            size: 19,
          ),
          label: Text('${docs.length}'),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Formulario de nueva publicación: título, descripción, materiales, fotos y pasos.
// ───────────────────────────────────────────────────────────────────────────
class _CrearPublicacionPage extends StatefulWidget {
  const _CrearPublicacionPage();
  @override
  State<_CrearPublicacionPage> createState() => _CrearPublicacionPageState();
}

class _CrearPublicacionPageState extends State<_CrearPublicacionPage> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _materiales = TextEditingController();
  final List<TextEditingController> _pasosTexto = [TextEditingController()];
  final List<XFile> _imagenes = [];
  bool _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _materiales.dispose();
    for (final control in _pasosTexto) {
      control.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFotos() async {
    if (_guardando) return;
    try {
      final disponibles = _maxFotos - _imagenes.length;
      if (disponibles == 0) {
        _mensaje(context, 'El máximo es de $_maxFotos fotografías.');
        return;
      }
      final elegidas = await ImagePicker().pickMultiImage(
        limit: disponibles == 1 ? null : disponibles,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (!mounted || elegidas.isEmpty) return;
      final paraAgregar = <XFile>[];
      for (final foto in elegidas.take(disponibles)) {
        final extension = foto.name.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
          if (!mounted) return;
          _mensaje(context, 'Usa fotografías JPG, PNG o WebP.');
          return;
        }
        if (await foto.length() > _maxBytesFoto) {
          if (mounted) {
            _mensaje(context, 'Cada fotografía debe pesar 5 MB como máximo.');
          }
          return;
        }
        paraAgregar.add(foto);
      }
      if (!mounted) return;
      setState(() => _imagenes.addAll(paraAgregar));
      if (elegidas.length > disponibles) {
        _mensaje(context, 'Solo se pueden adjuntar $_maxFotos fotografías.');
      }
    } catch (e) {
      if (mounted) _mensaje(context, _errorAmigable(e));
    }
  }

  String _tipoImagen(XFile imagen) {
    final extension = imagen.name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _publicar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    if (_imagenes.isEmpty) {
      _mensaje(context, 'Agrega por lo menos una fotografía.');
      return;
    }
    final pasos = _pasosTexto.map((p) => p.text.trim()).toList();
    if (pasos.any((p) => p.length < 8 || p.length > 1000)) {
      _mensaje(context, 'Cada paso debe tener entre 8 y 1000 caracteres.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mensaje(context, 'Tu sesión expiró. Ingresa nuevamente.');
      return;
    }
    setState(() => _guardando = true);
    final ref = FirebaseFirestore.instance.collection('publicaciones').doc();
    final subidas = <Reference>[];
    try {
      final urls = <String>[];
      for (var i = 0; i < _imagenes.length; i++) {
        final foto = _imagenes[i];
        final extension = foto.name.split('.').last.toLowerCase();
        final archivo = FirebaseStorage.instance.ref().child(
          'publicaciones/${user.uid}/${ref.id}/foto_$i.$extension',
        );
        subidas.add(archivo);
        final bytes = await foto.readAsBytes();
        if (bytes.length > _maxBytesFoto) {
          throw StateError('Hay una fotografía que supera los 5 MB.');
        }
        await archivo.putData(
          bytes,
          SettableMetadata(contentType: _tipoImagen(foto)),
        );
        urls.add(await archivo.getDownloadURL());
      }
      await ref.set({
        'titulo': _titulo.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'materiales': _materiales.text.trim(),
        'pasos': pasos,
        'fotos': urls,
        'autorUid': user.uid,
        'autorNombre': _autor(user),
        'creadoEn': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Si una subida falla, intentamos quitar las imágenes huérfanas.
      for (final archivo in subidas) {
        try {
          await archivo.delete();
        } catch (_) {
          // El error principal es más importante que uno de limpieza.
        }
      }
      if (mounted) {
        _mensaje(context, e is StateError ? e.message.toString() : _errorAmigable(e));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear guía de reciclaje')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Comparte una idea para reutilizar materiales',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titulo,
                  maxLength: 90,
                  decoration: const InputDecoration(
                    labelText: 'Título de la guía *',
                    hintText: 'Ej.: Macetero con una botella plástica',
                    border: OutlineInputBorder(),
                  ),
                  validator: (texto) => (texto?.trim().length ?? 0) < 3
                      ? 'Escribe un título de al menos 3 caracteres.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descripcion,
                  maxLength: 600,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '¿Qué aprenderemos a hacer? *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (texto) => (texto?.trim().length ?? 0) < 10
                      ? 'Agrega una descripción de al menos 10 caracteres.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _materiales,
                  maxLength: 400,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Materiales necesarios *',
                    hintText: 'Botella, tijeras, tierra, semillas...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (texto) => (texto?.trim().length ?? 0) < 3
                      ? 'Indica los materiales que se necesitan.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Fotografías *',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _guardando ? null : _elegirFotos,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                Text('${_imagenes.length}/$_maxFotos fotos · JPG, PNG o WebP · máximo 5 MB cada una'),
                const SizedBox(height: 10),
                if (_imagenes.isNotEmpty)
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagenes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 130,
                              height: 100,
                              child: FutureBuilder<Uint8List>(
                                future: _imagenes[i].readAsBytes(),
                                builder: (context, s) => s.hasData
                                    ? Image.memory(s.data!, fit: BoxFit.cover)
                                    : const Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 1,
                            top: 1,
                            child: IconButton.filledTonal(
                              tooltip: 'Quitar foto',
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _guardando
                                  ? null
                                  : () => setState(() => _imagenes.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Manual paso a paso *',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _guardando || _pasosTexto.length >= _maxPasos
                          ? null
                          : () => setState(
                                () => _pasosTexto.add(TextEditingController()),
                              ),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir paso'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _pasosTexto.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pasosTexto[i],
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Paso ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 8
                              ? 'Describe el paso con al menos 8 caracteres.'
                              : null,
                        ),
                      ),
                      if (_pasosTexto.length > 1)
                        IconButton(
                          tooltip: 'Eliminar paso',
                          onPressed: _guardando
                              ? null
                              : () => setState(() {
                                    final anterior = _pasosTexto.removeAt(i);
                                    // Evita desechar un TextField durante build.
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      anterior.dispose();
                                    });
                                  }),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _guardando ? null : _publicar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _verde,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(_guardando ? 'Subiendo fotografías...' : 'Publicar guía'),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Visor del dibujo: arriba fotos, abajo pasos, comentarios a la derecha,
// flechas independientes y X para cerrar la vista ampliada.
// ───────────────────────────────────────────────────────────────────────────
class _DetallePublicacionDialog extends StatelessWidget {
  const _DetallePublicacionDialog({
    required this.id,
    required this.publicacion,
    required this.solicitarLogin,
  });
  final String id;
  final Map<String, dynamic> publicacion;
  final Future<bool> Function() solicitarLogin;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: math.min(1160.0, size.width - 24),
        height: math.min(830.0, size.height - 24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.recycling, color: _verde),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      publicacion['titulo']?.toString() ?? 'Manual de reciclaje',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Minimizar y volver a las tarjetas',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(builder: (context, limites) {
                if (limites.maxWidth >= 790) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _GaleriaYManual(
                            id: id,
                            datos: publicacion,
                            solicitarLogin: solicitarLogin,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 4,
                        child: _PanelComentarios(
                          id: id,
                          solicitarLogin: solicitarLogin,
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _GaleriaYManual(
                      id: id,
                      datos: publicacion,
                      solicitarLogin: solicitarLogin,
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 450,
                      child: _PanelComentarios(
                        id: id,
                        solicitarLogin: solicitarLogin,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaleriaYManual extends StatefulWidget {
  const _GaleriaYManual({
    required this.id,
    required this.datos,
    required this.solicitarLogin,
  });
  final String id;
  final Map<String, dynamic> datos;
  final Future<bool> Function() solicitarLogin;

  @override
  State<_GaleriaYManual> createState() => _GaleriaYManualState();
}

class _GaleriaYManualState extends State<_GaleriaYManual> {
  int _foto = 0;
  int _paso = 0;

  Future<void> _reportar() async {
    if (!await widget.solicitarLogin() || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (widget.datos['autorUid'] == user.uid) {
      _mensaje(context, 'No puedes reportar tu propia publicación.');
      return;
    }
    const razones = [
      'Contenido no relacionado con reciclaje',
      'Lenguaje ofensivo',
      'Spam o publicidad',
      'Información falsa o peligrosa',
      'Otro',
    ];
    final motivo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('¿Por qué quieres reportar?'),
        children: [
          for (final razon in razones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, razon),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(razon),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      final reporte = FirebaseFirestore.instance
          .collection('publicaciones')
          .doc(widget.id)
          .collection('reportes')
          .doc(user.uid);
      if ((await reporte.get()).exists) {
        if (mounted) _mensaje(context, 'Ya reportaste esta publicación.');
        return;
      }
      await reporte.set({
        'autorUid': user.uid,
        'motivo': motivo,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _mensaje(context, 'Reporte recibido. Queda pendiente de revisión.');
      }
    } catch (e) {
      if (mounted) _mensaje(context, _errorAmigable(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotos = _fotos(widget.datos);
    final pasos = _pasos(widget.datos);
    final descripcion = widget.datos['descripcion']?.toString() ?? '';
    final materiales = widget.datos['materiales']?.toString() ?? '';
    final autor = widget.datos['autorNombre']?.toString() ?? 'EcoBrigadista';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Publicado por $autor', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text(descripcion),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _fondo,
                  child: fotos.isEmpty
                      ? const Icon(Icons.image_not_supported_outlined, size: 50)
                      : Image.network(
                          fotos[_foto],
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          ),
                        ),
                ),
                if (_foto > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Flecha(
                      icono: Icons.chevron_left,
                      accion: () => setState(() => _foto--),
                      descripcion: 'Fotografía anterior',
                    ),
                  ),
                if (_foto < fotos.length - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Flecha(
                      icono: Icons.chevron_right,
                      accion: () => setState(() => _foto++),
                      descripcion: 'Fotografía siguiente',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (fotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Foto ${_foto + 1} de ${fotos.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _verde),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          color: _fondo,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Materiales necesarios',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(materiales),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 190),
          decoration: BoxDecoration(
            color: _fondo,
            border: Border.all(color: _verde.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, color: _verde),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text('Manual paso a paso',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Text(pasos.isEmpty ? 'Sin pasos' : '${_paso + 1}/${pasos.length}'),
                  ],
                ),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 105),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: _paso > 0
                          ? IconButton(
                              onPressed: () => setState(() => _paso--),
                              icon: const Icon(Icons.arrow_back_ios_new),
                              tooltip: 'Paso anterior',
                            )
                          : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          pasos.isEmpty ? 'No hay instrucciones.' : pasos[_paso],
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: _paso < pasos.length - 1
                          ? IconButton(
                              onPressed: () => setState(() => _paso++),
                              icon: const Icon(Icons.arrow_forward_ios),
                              tooltip: 'Siguiente paso',
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _BotonLike(id: widget.id, solicitarLogin: widget.solicitarLogin),
            OutlinedButton.icon(
              onPressed: _reportar,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Reportar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Flecha extends StatelessWidget {
  const _Flecha({
    required this.icono,
    required this.accion,
    required this.descripcion,
  });
  final IconData icono;
  final VoidCallback accion;
  final String descripcion;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: IconButton.filledTonal(
        tooltip: descripcion,
        onPressed: accion,
        icon: Icon(icono),
      ),
    );
  }
}

class _PanelComentarios extends StatefulWidget {
  const _PanelComentarios({required this.id, required this.solicitarLogin});
  final String id;
  final Future<bool> Function() solicitarLogin;
  @override
  State<_PanelComentarios> createState() => _PanelComentariosState();
}

class _PanelComentariosState extends State<_PanelComentarios> {
  final _texto = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _comentar() async {
    if (_enviando) return;
    final comentario = _texto.text.trim();
    if (comentario.isEmpty) {
      _mensaje(context, 'Escribe un comentario primero.');
      return;
    }
    if (comentario.length > 500) {
      _mensaje(context, 'Máximo 500 caracteres por comentario.');
      return;
    }
    if (!await widget.solicitarLogin() || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _enviando = true);
    try {
      await FirebaseFirestore.instance
          .collection('publicaciones')
          .doc(widget.id)
          .collection('comentarios')
          .add({
        'autorUid': user.uid,
        'autorNombre': _autor(user),
        'texto': comentario,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      _texto.clear();
    } catch (e) {
      if (mounted) _mensaje(context, _errorAmigable(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.forum_outlined, color: _verde),
              SizedBox(width: 8),
              Expanded(
                child: Text('Comentarios',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('publicaciones')
                  .doc(widget.id)
                  .collection('comentarios')
                  .orderBy('creadoEn', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, s) {
                if (s.hasError) {
                  return Center(child: Text(_errorAmigable(s.error!)));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comentarios = s.data!.docs;
                if (comentarios.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay comentarios. ¡Deja el primero!'),
                  );
                }
                return ListView.separated(
                  itemCount: comentarios.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, i) {
                    final data = comentarios[i].data();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _fondo,
                        child: const Icon(Icons.person_outline, color: _verde),
                      ),
                      title: Text(
                        data['autorNombre']?.toString() ?? 'EcoBrigadista',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(data['texto']?.toString() ?? ''),
                      isThreeLine: false,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          TextField(
            controller: _texto,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe un comentario...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _enviando ? null : _comentar,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(_enviando ? 'Enviando' : 'Comentar'),
              style: FilledButton.styleFrom(backgroundColor: _verde),
            ),
          ),
        ],
      ),
    );
  }
}
