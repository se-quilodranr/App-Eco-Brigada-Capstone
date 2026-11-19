
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuscarBrigadasPage extends StatefulWidget {
  const BuscarBrigadasPage({super.key});

  @override
  State<BuscarBrigadasPage> createState() =>
      _BuscarBrigadasPageState();
}

class _BuscarBrigadasPageState
    extends State<BuscarBrigadasPage> {
  final supabase = Supabase.instance.client;
  final buscador = TextEditingController();

  List<Map<String, dynamic>> brigadas = [];
  String busqueda = '';
  bool cargando = true;

  String? get miId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    cargarBrigadas();
  }

  @override
  void dispose() {
    buscador.dispose();
    super.dispose();
  }

  Future<void> cargarBrigadas() async {
    try {
      final datos = await supabase
          .from('brigadas')
          .select(
            'id, nombre, comuna, descripcion, creador_id, estado',
          );

      if (!mounted) return;

      setState(() {
        brigadas = List<Map<String, dynamic>>.from(datos);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar: $e')),
      );
    }
  }

  void mostrarDetalle(Map<String, dynamic> brigada) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFDDF3E5),
                  child: Icon(
                    Icons.eco,
                    size: 40,
                    color: Color(0xFF176B4D),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${brigada['nombre']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '📍 ${brigada['comuna']}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  (brigada['descripcion'] ?? '').toString().isEmpty
                      ? 'Esta brigada no tiene descripción.'
                      : brigada['descripcion'].toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(
                  'Estado: ${brigada['estado']}',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = brigadas.where((brigada) {
      final nombre =
          brigada['nombre'].toString().toLowerCase();

      final comuna =
          brigada['comuna'].toString().toLowerCase();

      return nombre.contains(busqueda) ||
          comuna.contains(busqueda);
    }).toList();

    // La brigada creada por el usuario aparece primero.
    filtradas.sort((a, b) {
      final propiaA = a['creador_id'] == miId;
      final propiaB = b['creador_id'] == miId;

      if (propiaA && !propiaB) return -1;
      if (!propiaA && propiaB) return 1;

      return a['nombre']
          .toString()
          .compareTo(b['nombre'].toString());
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
        title: const Text('Buscar brigadas'),
      ),
      body: RefreshIndicator(
        onRefresh: cargarBrigadas,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Encuentra tu brigada 🌱',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF176B4D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Busca comunidades ambientales por nombre o comuna.',
            ),
            const SizedBox(height: 20),

            // BUSCADOR
            TextField(
              controller: buscador,
              onChanged: (texto) {
                setState(() {
                  busqueda = texto.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Nombre o comuna...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    buscador.clear();
                    setState(() => busqueda = '');
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (cargando)
              const Center(child: CircularProgressIndicator())
            else if (filtradas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No encontramos brigadas.',
                  ),
                ),
              )
            else
              ...filtradas.map((brigada) {
                final propia =
                    brigada['creador_id'] == miId;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: propia
                          ? const Color(0xFF176B4D)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDDF3E5),
                      child: Icon(
                        Icons.groups,
                        color: Color(0xFF176B4D),
                      ),
                    ),
                    title: Text(
                      brigada['nombre'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      propia
                          ? '⭐ Tu brigada · ${brigada['comuna']}'
                          : '📍 ${brigada['comuna']}',
                    ),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: () => mostrarDetalle(brigada),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
