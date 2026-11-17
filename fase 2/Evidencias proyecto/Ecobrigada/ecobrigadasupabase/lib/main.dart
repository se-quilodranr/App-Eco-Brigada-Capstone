import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/auth_page.dart';
import 'pages/brigadas_page.dart';
import 'pages/mapa_page.dart';
import 'pages/perfil_page.dart';
import 'pages/publicaciones_page.dart';
import 'services/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY. Revisa README.md.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const EcoBrigadaApp());
}

class EcoBrigadaApp extends StatelessWidget {
  const EcoBrigadaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EcoBrigada',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F8F4),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF21865A)),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF21865A),
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int indice = 0;
  late final StreamSubscription<AuthState> authSub;

  @override
  void initState() {
    super.initState();
    authSub = Api.db.auth.onAuthStateChange.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Error de sesión: $error');
      },
    );
  }

  @override
  void dispose() {
    authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conectado = Api.db.auth.currentUser != null;
    final vistas = <Widget>[
      const MapaPage(),
      const BrigadasPage(),
      const PublicacionesPage(),
      conectado
          ? const PerfilPage()
          : Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión para ver perfil'),
              ),
            ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded),
            SizedBox(width: 8),
            Text('EcoBrigada'),
          ],
        ),
        actions: [
          if (!conectado)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              ),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Ingresar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: indice, children: vistas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (i) => setState(() => indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Brigadas',
          ),
          NavigationDestination(
            icon: Icon(Icons.recycling_outlined),
            selectedIcon: Icon(Icons.recycling),
            label: 'Reciclaje',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

Future<bool> asegurarSesion(BuildContext context) async {
  if (Api.db.auth.currentUser != null) return true;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const AuthPage()));
  return Api.db.auth.currentUser != null;
}

void mostrarError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error.toString())));
}
