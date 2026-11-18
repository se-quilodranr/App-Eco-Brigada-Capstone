// EcoBrigada 3.0 - lib/main.dart
// Conexión a Supabase sin modificar el diseño ni los módulos de la aplicación.
// Supabase configurado con Project URL y Publishable Key.
// Los valores se pueden sobrescribir con --dart-define-from-file.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import 'core/design.dart';
import 'core/store.dart';
import 'pages/auth_page.dart';
import 'pages/brigadas_page.dart';
import 'pages/home_page.dart';
import 'pages/impacto_page.dart';
import 'pages/incidencias_page.dart';
import 'pages/mapa_page.dart';
import 'pages/extra_page.dart';
import 'pages/perfil_page.dart';
import 'pages/notificaciones_page.dart';
import 'original/publicaciones_page.dart';
import 'original/brigadas_page.dart' as original_brigades;

// OPCIÓN 1: pega aquí los datos de Project Settings > API Keys / Connect.
// Solo utiliza la Project URL y la Publishable Key (sb_publishable_...).
// Nunca pegues una Secret Key ni la clave service_role en Flutter.
const String _urlManual = 'https://imcvutrsvudbmuzgnbyd.supabase.co';
const String _publishableKeyManual =
    'sb_publishable_T7KyxRQUf4r370SLNP3p6Q_rSn2sF2Z';

// OPCIÓN 2 (recomendada): usa supabase_config.json en la raíz del proyecto.
// Si las variables se proporcionan con --dart-define, tienen prioridad.
const String _urlPorEntorno = String.fromEnvironment('SUPABASE_URL');
const String _keyPorEntorno = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

bool _esDatoValido(String valor) {
  return valor.isNotEmpty &&
      !valor.contains('PEGA_AQUI') &&
      !valor.contains('TU_PROJECT_REF');
}

bool _esUrlValida(String url) {
  final uri = Uri.tryParse(url);
  return _esDatoValido(url) &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final url = _urlPorEntorno.isNotEmpty ? _urlPorEntorno : _urlManual;
  final publishableKey = _keyPorEntorno.isNotEmpty
      ? _keyPorEntorno
      : _publishableKeyManual;

  if (!_esUrlValida(url) || !_esDatoValido(publishableKey)) {
    runApp(
      const _PantallaErrorInicio(
        titulo: 'Configura Supabase',
        mensaje:
            'Falta la Project URL o la Publishable Key.\n\n'
            'Opción 1: reemplaza las dos constantes al inicio de lib/main.dart.\n\n'
            'Opción 2: completa supabase_config.json y ejecuta Flutter con '
            '--dart-define-from-file=supabase_config.json.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  } catch (error, stackTrace) {
    debugPrint('Error al inicializar Supabase: $error\n$stackTrace');
    runApp(
      const _PantallaErrorInicio(
        titulo: 'No se pudo iniciar Supabase',
        mensaje:
            'Revisa la Project URL, la Publishable Key y tu conexión '
            'a internet. Si el problema continúa, consulta la consola de Flutter.',
      ),
    );
    return;
  }

  final store = EcoStore();
  try {
    await store.iniciar();
  } catch (error, stackTrace) {
    debugPrint('Error al cargar EcoBrigada: $error\n$stackTrace');
    runApp(
      const _PantallaErrorInicio(
        titulo: 'No se pudieron cargar los datos',
        mensaje:
            'Supabase se inicializó, pero EcoBrigada no pudo '
            'cargar su información. Revisa las tablas, permisos RLS '
            'y el error de la consola.',
      ),
    );
    return;
  }

  runApp(EcoBrigadaApp(store: store));
}

class _PantallaErrorInicio extends StatelessWidget {
  final String titulo;
  final String mensaje;

  const _PantallaErrorInicio({required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoBrigada 3.0',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco, size: 56, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(mensaje, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EcoBrigadaApp extends StatelessWidget {
  final EcoStore store;
  const EcoBrigadaApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoBrigada 3.0',
    debugShowCheckedModeBanner: false,
    theme: ecoTheme(),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) =>
          store.autenticado ? EcoShell(store: store) : AuthPage(store: store),
    ),
  );
}

class EcoShell extends StatefulWidget {
  final EcoStore store;
  const EcoShell({super.key, required this.store});
  @override
  State<EcoShell> createState() => _EcoShellState();
}

class _EcoShellState extends State<EcoShell> {
  int indice = 0;
  String filtroIncidencias = 'Todos';
  String vistaBrigadas = 'Todas';
  int revisionIncidencias = 0;

  void abrirIncidencias(String filtro) => setState(() {
    filtroIncidencias = filtro;
    revisionIncidencias++;
    indice = 2;
  });
  void abrirBrigadas(String vista) => setState(() {
    vistaBrigadas = vista;
    indice = 3;
  });
  static const secciones = [
    'Inicio',
    'EcoMapa',
    'Incidencias',
    'Brigadas',
    'EcoImpacto',
  ];
  static const iconos = [
    Icons.home_outlined,
    Icons.map_outlined,
    Icons.assignment_outlined,
    Icons.groups_outlined,
    Icons.bar_chart_outlined,
  ];
  static const iconosActivos = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.assignment_rounded,
    Icons.groups_rounded,
    Icons.bar_chart_rounded,
  ];

  void cambiar(int i) => setState(() {
    indice = i;
    if (i == 2) {
      filtroIncidencias = 'Todos';
      revisionIncidencias++;
    }
    if (i == 3) vistaBrigadas = 'Todas';
  });
  void nuevoReporte({dynamic punto}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NuevoReportePage(store: widget.store, initialPunto: punto),
      ),
    );
  }

  void detalle(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleReportePage(store: widget.store, id: id),
      ),
    );
  }

  void paginaExtra(String opcion) {
    if (opcion == 'comunidad') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Comunidad y reciclaje')),
            body: const PublicacionesPage(),
          ),
        ),
      );
      return;
    }
    if (opcion == 'brigadas_originales') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Brigadas y actividades anteriores'),
            ),
            body: const original_brigades.BrigadasPage(),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtraPage(store: widget.store, opcion: opcion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final s = widget.store;
      final wide = MediaQuery.sizeOf(context).width >= 950;
      final paginas = <Widget>[
        EcoHome(
          store: s,
          irA: cambiar,
          abrirIncidencias: abrirIncidencias,
          abrirBrigadas: abrirBrigadas,
          nuevoReporte: () => nuevoReporte(),
          verReporte: detalle,
          irComunidad: () => paginaExtra('comunidad'),
        ),
        EcoMapa(
          store: s,
          crearEn: (p) => nuevoReporte(punto: p),
          verReporte: detalle,
          verBrigada: (id) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetalleBrigadaPage(store: s, brigadaId: id),
            ),
          ),
        ),
        EcoIncidencias(
          key: ValueKey(revisionIncidencias),
          store: s,
          nuevoReporte: () => nuevoReporte(),
          verReporte: detalle,
          filtroInicial: filtroIncidencias,
        ),
        EcoBrigadas(store: s, vista: vistaBrigadas,
          cambiarVista: (v) => setState(() => vistaBrigadas = v)),
        EcoImpacto(store: s),
      ];
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          titleSpacing: wide ? 26 : 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: EcoColors.forest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: EcoColors.lime,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EcoBrigada',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: EcoColors.forest,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'GESTIÓN AMBIENTAL',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: EcoColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (s.pendientesSinConexion > 0)
              TextButton.icon(
                onPressed: () async {
                  await s.reenviarPendientes();
                },
                icon: const Icon(Icons.sync),
                label: Text('${s.pendientesSinConexion} pendientes'),
              ),
            IconButton(
              tooltip: 'Notificaciones',
              icon: Badge(
                isLabelVisible: s.notificaciones.any(
                  (n) => n['leida_en'] == null,
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NotificacionesPage(store: s)),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar información',
              onPressed: () => s.refrescar(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 5),
            PopupMenuButton<String>(
              tooltip: 'Mi cuenta y opciones',
              onSelected: (v) async {
                if (v == 'iniciar') {
                  if (!context.mounted) return;
                  await Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => AuthPage(store: s)));
                } else if (v == 'perfil') {
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EcoPerfil(store: s)),
                  );
                } else if (v == 'salir') {
                  await s.salir();
                } else {
                  paginaExtra(v);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'cuenta',
                  child: Text(
                    s.nombreUsuario,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (s.autenticado)
                  const PopupMenuItem(
                    value: 'salir',
                    child: Text('Cerrar sesión'),
                  ),
                const PopupMenuItem(value: 'perfil', child: Text('Mi perfil')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'guias',
                  child: Text('Guías ambientales'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'comunidad',
                  child: Text('Publicaciones y reciclaje'),
                ),
                const PopupMenuItem(
                  value: 'brigadas_originales',
                  child: Text('Mis brigadas y actividades anteriores'),
                ),
                const PopupMenuItem(value: 'logros', child: Text('EcoLogros')),
                const PopupMenuItem(
                  value: 'acerca',
                  child: Text('Sobre EcoBrigada'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CircleAvatar(
                  backgroundColor: EcoColors.mint,
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: EcoColors.forest,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                backgroundColor: Colors.white,
                selectedIndex: indice,
                labelType: NavigationRailLabelType.all,
                minWidth: 104,
                groupAlignment: -0.7,
                onDestinationSelected: cambiar,
                leading: const Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Icon(
                    Icons.nature_people_rounded,
                    color: EcoColors.green,
                    size: 32,
                  ),
                ),
                destinations: [
                  for (var i = 0; i < secciones.length; i++)
                    NavigationRailDestination(
                      icon: Icon(iconos[i]),
                      selectedIcon: Icon(iconosActivos[i]),
                      label: Text(secciones[i]),
                    ),
                ],
              ),
            Expanded(child: paginas[indice]),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: indice,
                onDestinationSelected: cambiar,
                destinations: [
                  for (var i = 0; i < secciones.length; i++)
                    NavigationDestination(
                      icon: Icon(iconos[i]),
                      selectedIcon: Icon(iconosActivos[i]),
                      label: secciones[i],
                    ),
                ],
              ),
      );
    },
  );
}

/// Compatibilidad con las páginas Supabase originales conservadas.
Future<bool> asegurarSesion(BuildContext context) async {
  if (Supabase.instance.client.auth.currentUser != null) return true;
  final store = context.findAncestorWidgetOfExactType<EcoShell>()?.store;
  if (store == null) return false;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => AuthPage(store: store)));
  return Supabase.instance.client.auth.currentUser != null;
}

void mostrarError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}
