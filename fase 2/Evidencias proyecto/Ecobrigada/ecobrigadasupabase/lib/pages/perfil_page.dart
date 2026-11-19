import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import 'incidencias_page.dart';
import 'brigadas_page.dart';

class EcoPerfil extends StatelessWidget {
  final EcoStore store;
  const EcoPerfil({super.key, required this.store});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    final usuario = store.usuario;
    final rol = store.esAdmin
        ? 'Administrador'
        : store.esBrigadista
        ? 'Líder de brigada'
        : 'Ciudadano';
    final propios = store.reportes
        .where((r) => r.creadorUid == store.uid)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              EcoPanel(
                child: Column(
                  children: [
                    if (store.avatarPath == null)
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: EcoColors.mint,
                        child: Icon(
                          Icons.person_rounded,
                          color: EcoColors.green,
                          size: 43,
                        ),
                      )
                    else
                      FutureBuilder<String>(
                        future: store.fotos.urlTemporal(store.avatarPath!),
                        builder: (context, s) => s.hasData
                            ? CircleAvatar(
                                radius: 40,
                                backgroundImage: NetworkImage(s.data!),
                              )
                            : const CircleAvatar(
                                radius: 40,
                                child: Icon(Icons.person),
                              ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final imagen = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (imagen != null) {
                            await store.actualizarAvatar(imagen);
                          }
                        } catch (e) {
                          if (context.mounted) mostrarError(context, e);
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Cambiar fotografía'),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      store.nombreUsuario,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      rol,
                      style: const TextStyle(
                        color: EcoColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      usuario?.email ?? 'Sin correo',
                      style: const TextStyle(color: EcoColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 19),
              const EcoSection(title: 'Mi actividad'),
              responsiveWrap([
                Indicador(
                  titulo: 'Mis reportes',
                  valor: '$propios',
                  icono: Icons.assignment_outlined,
                ),
                Indicador(
                  titulo: 'Brigadas que lidero',
                  valor:
                      '${store.brigadas.where((b) => b.liderUid == store.uid).length}',
                  icono: Icons.groups_outlined,
                  onTap: () {
                    final misBrigadas = store.brigadas
                        .where((b) => b.liderUid == store.uid)
                        .toList();

                    if (misBrigadas.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Todavía no lideras una brigada.'),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleBrigadaPage(
                          store: store,
                          brigadaId: misBrigadas.first.id,
                        ),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 21),
              const EcoSection(title: 'Incidencias que tomé'),
              if (!store.reportes.any(
                (r) => r.tomadaPor == store.uid && store.autenticado,
              ))
                const EcoPanel(
                  child: Text('Todavía no has tomado incidencias.'),
                ),
              for (final r in store.reportes.where(
                (r) => store.autenticado && r.tomadaPor == store.uid,
              ))
                ReporteTile(
                  reporte: r,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetalleReportePage(store: store, id: r.id),
                    ),
                  ),
                ),
              const SizedBox(height: 17),
              OutlinedButton.icon(
                onPressed: () async {
                  await store.salir();
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
