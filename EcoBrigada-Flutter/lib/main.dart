import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/brigadas_page.dart';
import 'pages/perfil_page.dart';
import 'pages/mapa_page.dart';
import 'pages/publicaciones_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EcoBrigadaApp());
}

class EcoBrigadaApp extends StatelessWidget {
  const EcoBrigadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoBrigada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF21865A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8F4),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  static const sections = ['Inicio', 'Brigada', 'Mapa', 'Guías', 'Logros'];
  static const icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.map_outlined,
    Icons.auto_stories_outlined,
    Icons.emoji_events_outlined,
  ];

  void navigateTo(int index) {
    if ((index == 1 || index == 4) &&
        FirebaseAuth.instance.currentUser == null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¡Únete a EcoBrigada!'),
          content: Text(
            'Para acceder a ${sections[index]} necesitas iniciar sesión o crear una cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAuth(false, index);
              },
              child: const Text('Ingresar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAuth(true, index);
              },
              child: const Text('Registrarme'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => selectedIndex = index);
  }

  Future<void> openAuth(bool register, int destination) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AuthPage(initialRegister: register)),
    );
    if (!mounted) return;
    if (success == true) setState(() => selectedIndex = destination);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, color: Color(0xFF21865A)),
            SizedBox(width: 8),
            Text('EcoBrigada', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (user == null)
            TextButton.icon(
              onPressed: () => openAuth(false, selectedIndex),
              icon: const Icon(Icons.login),
              label: const Text('Ingresar'),
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final datos = snapshot.data?.data();
                final nombre = (datos?['nombre'] ?? '').toString();
                final apellidos = (datos?['apellidos'] ?? '').toString();
                final nombreCompleto = '$nombre $apellidos'.trim();

                return PopupMenuButton<String>(
                  tooltip: 'Mi cuenta',
                  icon: const Icon(Icons.account_circle_outlined),
                  onSelected: (value) async {
                    if (value == 'perfil') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PerfilPage()),
                      );
                    } else if (value == 'logout') {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) setState(() => selectedIndex = 0);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'perfil',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              nombreCompleto.isEmpty
                                  ? 'Mi perfil'
                                  : nombreCompleto,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 10),
                          Text('Cerrar sesión'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(width: 12),
        ],
      ),

      body: selectedIndex == 0
          ? const WelcomeContent()
          : selectedIndex == 1
          ? const BrigadasPage()
          : selectedIndex == 2
          ? const MapaPage()
          : selectedIndex == 3
          ? PublicacionesPage(
              onSolicitarLogin: () async {
                await openAuth(false, 3);
                return FirebaseAuth.instance.currentUser != null;
              },
            )
          : SectionContent(
              title: sections[selectedIndex],
              icon: icons[selectedIndex],
            ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: navigateTo,
        destinations: [
          for (var i = 0; i < sections.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: sections[i]),
        ],
      ),
    );
  }
}

class WelcomeContent extends StatelessWidget {
  const WelcomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF21865A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.forest, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text(
                '¡Cuidemos nuestro planeta!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Conecta con tu comunidad, descubre iniciativas ecológicas y gana logros.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Explora EcoBrigada',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.groups, color: Colors.green),
            title: Text('Brigada'),
            subtitle: Text('Participa en iniciativas ambientales'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.map, color: Colors.green),
            title: Text('Mapa'),
            subtitle: Text('Descubre puntos ecológicos'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.article, color: Colors.green),
            title: Text('Publicaciones'),
            subtitle: Text('Publica y descubre manuales de reciclaje'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.emoji_events, color: Colors.green),
            title: Text('Logros'),
            subtitle: Text('Suma puntos por tus acciones'),
          ),
        ),
      ],
    );
  }
}

class SectionContent extends StatelessWidget {
  final String title;
  final IconData icon;
  const SectionContent({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 76, color: const Color(0xFF21865A)),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Próximamente: contenido de esta sección.'),
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  final bool initialRegister;
  const AuthPage({super.key, required this.initialRegister});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final lastNameController = TextEditingController();
  final rutController = TextEditingController();
  final emailController = TextEditingController();
  final communeController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();

  DateTime? birthDate;
  late bool register;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    register = widget.initialRegister;
  }

  @override
  void dispose() {
    nameController.dispose();
    lastNameController.dispose();
    rutController.dispose();
    emailController.dispose();
    communeController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? requiredField(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Este campo es obligatorio'
        : null;
  }

  String cleanRut(String value) =>
      value.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();

  String? validateRut(String? value) {
    final rut = cleanRut(value ?? '');
    if (rut.length < 8 || rut.length > 9) return 'Ingresa un RUT válido';

    final body = rut.substring(0, rut.length - 1);
    final digit = rut.substring(rut.length - 1);
    if (!RegExp(r'^\d{7,8}$').hasMatch(body)) {
      return 'Ingresa un RUT válido';
    }

    var sum = 0;
    var factor = 2;
    for (var i = body.length - 1; i >= 0; i--) {
      sum += int.parse(body[i]) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }
    final result = 11 - (sum % 11);
    final expected = result == 11
        ? '0'
        : result == 10
        ? 'K'
        : '$result';
    return digit == expected ? null : 'El dígito verificador no es válido';
  }

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget field({
    required TextEditingController controller,
    required String label,
    bool requiredValue = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool hidden = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: hidden,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? (requiredValue ? requiredField : null),
      ),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (register) {
        final credentials = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final user = credentials.user!;

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
              'uid': user.uid,
              'nombre': nameController.text.trim(),
              'apellidos': lastNameController.text.trim(),
              'rut': cleanRut(rutController.text),
              'correo': email,
              'fechaNacimiento': Timestamp.fromDate(birthDate!),
              'comuna': communeController.text.trim(),
              'direccion': addressController.text.trim(),
              'puntos': 0,
              'fechaRegistro': FieldValue.serverTimestamp(),
            });

        await user.updateDisplayName(
          '${nameController.text.trim()} ${lastNameController.text.trim()}',
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          error = switch (e.code) {
            'email-already-in-use' => 'Este correo ya está registrado.',
            'invalid-email' => 'El correo no es válido.',
            'weak-password' => 'La contraseña es demasiado débil.',
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'Correo o contraseña incorrectos.',
            _ => e.message ?? 'No fue posible autenticarte.',
          };
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          error =
              'Error al guardar el perfil: ${e.message ?? e.code}. '
              'Revisa Firestore y sus reglas.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Ocurrió un error inesperado. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(register ? 'Crear cuenta' : 'Iniciar sesión')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco, size: 60, color: Color(0xFF21865A)),
                      const SizedBox(height: 12),
                      Text(
                        register ? 'Únete a EcoBrigada' : 'Bienvenido de nuevo',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (register) ...[
                        field(controller: nameController, label: 'Nombre *'),
                        field(
                          controller: lastNameController,
                          label: 'Apellidos *',
                        ),
                        field(
                          controller: rutController,
                          label: 'RUT *',
                          validator: validateRut,
                        ),
                      ],
                      field(
                        controller: emailController,
                        label: 'Correo electrónico *',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      if (register) ...[
                        FormField<DateTime>(
                          validator: (_) => birthDate == null
                              ? 'Selecciona tu fecha de nacimiento'
                              : null,
                          builder: (state) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: loading
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            birthDate ?? DateTime(2000),
                                        firstDate: DateTime(1900),
                                        lastDate: now,
                                        helpText: 'Fecha de nacimiento',
                                        cancelText: 'Cancelar',
                                        confirmText: 'Aceptar',
                                      );
                                      if (date != null) {
                                        setState(() => birthDate = date);
                                        state.didChange(date);
                                      }
                                    },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha de nacimiento *',
                                  border: const OutlineInputBorder(),
                                  errorText: state.errorText,
                                  suffixIcon: const Icon(Icons.calendar_month),
                                ),
                                child: Text(
                                  birthDate == null
                                      ? 'Seleccionar fecha'
                                      : formatDate(birthDate!),
                                ),
                              ),
                            ),
                          ),
                        ),
                        field(controller: communeController, label: 'Comuna *'),
                        field(
                          controller: addressController,
                          label: 'Dirección (opcional)',
                          requiredValue: false,
                        ),
                      ],
                      field(
                        controller: passwordController,
                        label: 'Contraseña *',
                        hidden: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña es obligatoria';
                          }

                          // Las nuevas reglas solo se aplican al registro
                          if (!register) return null;

                          // Validar longitud
                          if (value.length < 6 || value.length > 8) {
                            return 'Debe tener entre 6 y 8 caracteres';
                          }

                          // Validar mayúscula
                          if (!RegExp(r'[A-Z]').hasMatch(value)) {
                            return 'Debe contener al menos una mayúscula';
                          }

                          // Validar número
                          if (!RegExp(r'[0-9]').hasMatch(value)) {
                            return 'Debe contener al menos un número';
                          }

                          // Validar carácter especial
                          if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
                            return 'Debe contener al menos un carácter especial';
                          }

                          return null;
                        },
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : submit,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              loading
                                  ? 'Procesando...'
                                  : register
                                  ? 'Registrarme'
                                  : 'Ingresar',
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                register = !register;
                                error = null;
                              }),
                        child: Text(
                          register
                              ? '¿Ya tienes cuenta? Inicia sesión'
                              : '¿No tienes cuenta? Regístrate',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
