import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pages/brigadas_page.dart';

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
  static const sections = ['Inicio', 'Brigada', 'Mapa', 'Noticias', 'Logros'];
  static const icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.map_outlined,
    Icons.article_outlined,
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
            PopupMenuButton<String>(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) async {
                if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) setState(() => selectedIndex = 0);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(user.email ?? 'Mi cuenta'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar sesión'),
                ),
              ],
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: selectedIndex == 0
            ? const WelcomeContent()
            : selectedIndex == 1
            ? const BrigadasPage()
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
            title: Text('Noticias'),
            subtitle: Text('Entérate de las novedades ambientales'),
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      final uid = credentials.user!.uid;

      await credentials.user!.updateDisplayName(
        nameController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({
            'uid': uid,
            'nombre': nameController.text.trim(),
            'correo': email,
            'puntos': 0,
            'fechaRegistro': FieldValue.serverTimestamp(),
          });
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }

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
            'Error al guardar el perfil: ${e.message ?? e.code}. Revisa Firestore y sus reglas.';
      });
    }

  } catch (_) {
    if (mounted) {
      setState(() {
        error = 'Ocurrió un error inesperado. Intenta nuevamente.';
      });
    }

  } finally {
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
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
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? 'Ingresa un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
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
