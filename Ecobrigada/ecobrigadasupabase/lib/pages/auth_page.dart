import 'package:flutter/material.dart';

import '../services/api.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final clave = TextEditingController();
  bool registro = false;
  bool ocupado = false;
  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    clave.dispose();
    super.dispose();
  }

  Future<void> enviar() async {
    if (!form.currentState!.validate()) return;
    setState(() => ocupado = true);
    try {
      if (registro) {
        final activa = await Api.registrarse(
          nombre.text,
          correo.text,
          clave.text,
        );
        if (!mounted) return;
        if (!activa) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cuenta creada. Confirma tu correo antes de ingresar.',
              ),
            ),
          );
          setState(() => registro = false);
          return;
        }
      } else {
        await Api.ingresar(correo.text, clave.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(registro ? 'Crear cuenta' : 'Iniciar sesión')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.eco, color: Color(0xFF21865A), size: 74),
                const SizedBox(height: 16),
                Text(
                  registro ? 'Únete a EcoBrigada' : 'Bienvenido de vuelta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (registro) ...[
                  TextFormField(
                    controller: nombre,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Ingresa un nombre válido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => !(v ?? '').contains('@')
                      ? 'Ingresa un correo válido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: clave,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: ocupado ? null : enviar,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ocupado
                        ? const CircularProgressIndicator()
                        : Text(registro ? 'Registrarme' : 'Ingresar'),
                  ),
                ),
                TextButton(
                  onPressed: ocupado
                      ? null
                      : () => setState(() => registro = !registro),
                  child: Text(
                    registro
                        ? '¿Ya tienes cuenta? Ingresar'
                        : '¿No tienes cuenta? Registrarme',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
