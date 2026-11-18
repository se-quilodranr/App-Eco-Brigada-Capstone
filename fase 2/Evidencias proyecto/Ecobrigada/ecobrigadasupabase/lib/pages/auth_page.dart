import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/registro_validacion.dart';
import '../core/store.dart';
import '../widgets/common.dart';

class AuthPage extends StatefulWidget {
  final EcoStore store;
  const AuthPage({super.key, required this.store});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formulario = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final rut = TextEditingController();
  final comuna = TextEditingController();
  final direccion = TextEditingController();
  final correo = TextEditingController();
  final clave = TextEditingController();
  bool registro = false;
  bool procesando = false;
  bool ocultar = true;

  @override
  void dispose() {
    nombre.dispose(); apellido.dispose(); rut.dispose(); comuna.dispose();
    direccion.dispose(); correo.dispose(); clave.dispose();
    super.dispose();
  }

  Future<void> enviar() async {
    if (!(formulario.currentState?.validate() ?? false)) return;
    setState(() => procesando = true);
    try {
      if (registro) {
        await widget.store.registrar(
          nombre: nombre.text,
          apellido: apellido.text,
          rut: rut.text,
          correo: correo.text,
          password: clave.text,
          comuna: comuna.text,
          direccion: direccion.text,
        );
      } else {
        await widget.store.acceder(correo.text, clave.text);
      }
      if (mounted && Navigator.of(context).canPop()) Navigator.pop(context);
    } catch (e) {
      if (mounted && e.toString().contains('Verifica tu correo')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        setState(() => registro = false);
      } else if (mounted) {
        mostrarError(context, e);
      }
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(registro ? 'Crear cuenta' : 'Mi cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EcoPanel(
              child: Form(
                key: formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: EcoColors.mint,
                      child: Icon(Icons.eco_rounded, color: EcoColors.green, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text(registro ? 'Únete a EcoBrigada' : 'Bienvenido de nuevo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                        color: EcoColors.forest)),
                    const SizedBox(height: 7),
                    const Text('Participa en el cambio ambiental de tu comunidad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: EcoColors.muted)),
                    const SizedBox(height: 23),
                    if (registro) ...[
                      TextFormField(controller: nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nombre *',
                          prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => RegistroValidacion.obligatorio(v, 'tu nombre')),
                      const SizedBox(height: 12),
                      TextFormField(controller: apellido,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Apellido *'),
                        validator: (v) => RegistroValidacion.obligatorio(v, 'tu apellido')),
                      const SizedBox(height: 12),
                      TextFormField(controller: rut,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'RUT *',
                          hintText: '12.345.678-5'),
                        validator: RegistroValidacion.rut),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo electrónico *',
                        prefixIcon: Icon(Icons.alternate_email)),
                      validator: RegistroValidacion.correo),
                    const SizedBox(height: 12),
                    TextFormField(controller: clave, obscureText: ocultar,
                      autofillHints: [registro ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        suffixIcon: IconButton(
                          tooltip: ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          onPressed: () => setState(() => ocultar = !ocultar),
                          icon: Icon(ocultar
                            ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                      validator: registro ? RegistroValidacion.contrasena
                        : (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña.' : null),
                    if (registro) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 6, bottom: 12),
                        child: Text('La contraseña debe tener al menos 6 caracteres.',
                          style: TextStyle(color: EcoColors.muted, fontSize: 12)),
                      ),
                      TextFormField(controller: comuna,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Comuna *',
                          hintText: 'Ej.: Concepción'),
                        validator: (v) => RegistroValidacion.obligatorio(v, 'tu comuna')),
                      const SizedBox(height: 12),
                      TextFormField(controller: direccion,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Dirección (opcional)',
                          hintText: 'Calle y número',
                          helperText: 'Puedes dejar este campo vacío.'),
                        validator: (v) => (v ?? '').trim().length > 200
                          ? 'La dirección puede tener hasta 200 caracteres.' : null),
                      const SizedBox(height: 12),
                      const Text('* Campos obligatorios',
                        style: TextStyle(fontSize: 11, color: EcoColors.muted)),
                    ],
                    const SizedBox(height: 21),
                    FilledButton(
                      onPressed: procesando ? null : enviar,
                      child: Text(procesando ? 'Procesando...'
                        : registro ? 'Crear cuenta' : 'Ingresar'),
                    ),
                    TextButton(
                      onPressed: procesando ? null : () {
                        setState(() {registro = !registro; formulario.currentState?.reset();});
                      },
                      child: Text(registro ? 'Ya tengo una cuenta' : 'Quiero registrarme'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
