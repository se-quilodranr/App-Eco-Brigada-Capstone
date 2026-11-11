import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool subiendoFoto = false;

  Future<void> cambiarFoto() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null || subiendoFoto) return;

    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (archivo == null) return;

      final Uint8List imagen = await archivo.readAsBytes();

      if (imagen.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('La fotografía no puede superar los 5 MB');
      }

      final nombreArchivo = archivo.name.toLowerCase();
      String tipoImagen;

      if (nombreArchivo.endsWith('.png')) {
        tipoImagen = 'image/png';
      } else if (nombreArchivo.endsWith('.webp')) {
        tipoImagen = 'image/webp';
      } else if (nombreArchivo.endsWith('.jpg') ||
          nombreArchivo.endsWith('.jpeg')) {
        tipoImagen = 'image/jpeg';
      } else {
        throw Exception('Selecciona una imagen JPG, PNG o WebP');
      }

      setState(() => subiendoFoto = true);

      final referencia = FirebaseStorage.instance.ref().child(
        'perfiles/${usuario.uid}/foto',
      );

      await referencia.putData(
        imagen,
        SettableMetadata(contentType: tipoImagen),
      );

      final urlFoto = await referencia.getDownloadURL();

      // Actualizar la fotografía y su versión en Firestore.
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .update({
            'fotoUrl': urlFoto,
            'fotoActualizada': FieldValue.serverTimestamp(),
          });

      // Evitar que Flutter siga mostrando la imagen anterior.
      await NetworkImage(urlFoto).evict();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotografía actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la fotografía: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => subiendoFoto = false);
      }
    }
  }

  Widget crearDato({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono, color: const Color(0xFF21865A)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(valor.trim().isEmpty ? 'No especificado' : valor),
      ),
    );
  }

  String formatearFecha(dynamic valor) {
    if (valor is Timestamp) {
      final fecha = valor.toDate();

      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');

      return '$dia/$mes/${fecha.year}';
    }

    return 'No especificada';
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tu perfil'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: const Color(0xFF21865A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF4F8F4),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuario.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al obtener los datos del perfil'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final datos = snapshot.data!.data();

          if (datos == null) {
            return const Center(
              child: Text('No se encontraron datos de perfil'),
            );
          }

          final nombre = (datos['nombre'] ?? '').toString();
          final apellidos = (datos['apellidos'] ?? '').toString();

          final nombreCompleto = '$nombre $apellidos'.trim();

          final fotoUrl = (datos['fotoUrl'] ?? '').toString();

          final fechaNacimiento = formatearFecha(datos['fechaNacimiento']);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Fotografía del usuario
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 65,
                          backgroundColor: const Color(0xFFD8EBDD),
                          backgroundImage: fotoUrl.isNotEmpty
                              ? NetworkImage(fotoUrl)
                              : null,
                          child: fotoUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 75,
                                  color: Color(0xFF21865A),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton.filled(
                            tooltip: 'Cambiar fotografía',
                            onPressed: subiendoFoto ? null : cambiarFoto,
                            icon: const Icon(Icons.camera_alt),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (subiendoFoto)
                    const Center(child: CircularProgressIndicator()),

                  const SizedBox(height: 12),

                  Text(
                    nombreCompleto.isEmpty
                        ? 'Usuario EcoBrigada'
                        : nombreCompleto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF21865A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    usuario.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Información personal',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 14),

                  crearDato(
                    titulo: 'Nombre',
                    valor: nombre,
                    icono: Icons.person_outline,
                  ),

                  crearDato(
                    titulo: 'Apellidos',
                    valor: apellidos,
                    icono: Icons.badge_outlined,
                  ),

                  crearDato(
                    titulo: 'RUT',
                    valor: (datos['rut'] ?? '').toString(),
                    icono: Icons.assignment_ind_outlined,
                  ),

                  crearDato(
                    titulo: 'Correo electrónico',
                    valor: (datos['correo'] ?? usuario.email ?? '').toString(),
                    icono: Icons.email_outlined,
                  ),

                  crearDato(
                    titulo: 'Fecha de nacimiento',
                    valor: fechaNacimiento,
                    icono: Icons.calendar_month_outlined,
                  ),

                  crearDato(
                    titulo: 'Comuna',
                    valor: (datos['comuna'] ?? '').toString(),
                    icono: Icons.location_city_outlined,
                  ),

                  crearDato(
                    titulo: 'Dirección',
                    valor: (datos['direccion'] ?? '').toString(),
                    icono: Icons.home_outlined,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
