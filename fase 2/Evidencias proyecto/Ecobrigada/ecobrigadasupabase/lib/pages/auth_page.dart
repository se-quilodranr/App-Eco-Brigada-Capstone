
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design.dart';
import '../core/registro_validacion.dart';
import '../core/store.dart';
import '../widgets/common.dart';

class AuthPage extends StatefulWidget {
  final EcoStore store;

  const AuthPage({
    super.key,
    required this.store,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formulario = GlobalKey<FormState>();

  // ÚNICOS CAMPOS DEL REGISTRO
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final clave = TextEditingController();

  String? comunaSeleccionada;

  final List<String> comunas = [
    'Coronel',
    'Concepción',
    'Lota',
    'San Pedro de la Paz',
  ];

  bool registro = false;
  bool procesando = false;
  bool ocultar = true;

  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    clave.dispose();
    super.dispose();
  }

  // MENSAJES
  void mostrarMensaje(
    String mensaje, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? Colors.red.shade700 : EcoColors.green,
      ),
    );
  }

  // REGISTRARSE O INICIAR SESIÓN
  Future<void> enviar() async {
    if (!(formulario.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => procesando = true);

    try {
      if (registro) {
        // REGISTRO CON SUPABASE AUTH
        // No solicita RUT, apellido ni dirección.

        final respuesta =
            await Supabase.instance.client.auth.signUp(
          email: correo.text.trim(),
          password: clave.text,
          data: {
            'nombre': nombre.text.trim(),
            'comuna': comunaSeleccionada,
          },
        );

        if (!mounted) return;

        if (respuesta.user == null) {
          mostrarMensaje(
            'No se pudo completar el registro.',
            error: true,
          );
          return;
        }

        // Si Supabase exige confirmación de correo.
        if (respuesta.session == null) {
          setState(() {
            registro = false;
          });

          mostrarMensaje(
            'Cuenta registrada. Revisa tu correo '
            'para confirmar tu cuenta.',
          );
        } else {
          mostrarMensaje(
            '¡Bienvenido a EcoBrigada! 🌱',
          );

          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      } else {
        // INICIO DE SESIÓN
        await widget.store.acceder(
          correo.text.trim(),
          clave.text,
        );

        if (!mounted) return;

        mostrarMensaje(
          '¡Sesión iniciada correctamente!',
        );

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      final credencialesInvalidas =
          !registro &&
          (e.code == 'invalid_credentials' ||
              e.message.toLowerCase().contains(
                'invalid login credentials',
              ));

      mostrarMensaje(
        credencialesInvalidas
            ? 'Correo o contraseña incorrectos.'
            : 'Error de autenticación: ${e.message}',
        error: true,
      );
    } catch (e) {
      mostrarMensaje(
        'Ocurrió un error: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => procesando = false);
      }
    }
  }

  // CAMBIAR ENTRE LOGIN Y REGISTRO
  void cambiarModo() {
    if (procesando) return;

    formulario.currentState?.reset();

    setState(() {
      registro = !registro;
      comunaSeleccionada = null;
      ocultar = true;
    });

    nombre.clear();
    clave.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),

      appBar: AppBar(
        title: Text(
          registro ? 'Crear cuenta' : 'Iniciar sesión',
        ),
        backgroundColor: EcoColors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 480,
            ),

            child: EcoPanel(
              child: Form(
                key: formulario,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    // ICONO ECOBRIGADA
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: EcoColors.mint,
                      child: Icon(
                        Icons.eco_rounded,
                        color: EcoColors.green,
                        size: 42,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      registro
                          ? 'Únete a EcoBrigada'
                          : '¡Bienvenido de nuevo!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: EcoColors.forest,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      registro
                          ? 'Crea tu cuenta y ayuda a cuidar '
                            'el medioambiente.'
                          : 'Ingresa a tu comunidad ambiental.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: EcoColors.muted,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // NOMBRE SOLO EN REGISTRO
                    if (registro) ...[
                      TextFormField(
                        controller: nombre,
                        textCapitalization:
                            TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Tu nombre',
                          prefixIcon:
                              Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (valor) =>
                            RegistroValidacion.obligatorio(
                          valor,
                          'tu nombre',
                        ),
                      ),

                      const SizedBox(height: 14),
                    ],

                    // CORREO ELECTRÓNICO
                    TextFormField(
                      controller: correo,
                      keyboardType:
                          TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        hintText: 'ejemplo@correo.com',
                        prefixIcon:
                            Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          RegistroValidacion.correo,
                    ),

                    const SizedBox(height: 14),

                    // CONTRASEÑA
                    TextFormField(
                      controller: clave,
                      obscureText: ocultar,
                      autofillHints: [
                        registro
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon:
                            const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: ocultar
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () {
                            setState(() {
                              ocultar = !ocultar;
                            });
                          },
                          icon: Icon(
                            ocultar
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: registro
                          ? RegistroValidacion.contrasena
                          : (valor) {
                              if ((valor ?? '').isEmpty) {
                                return 'Ingresa tu contraseña.';
                              }
                              return null;
                            },
                    ),

                    // COMUNA SOLO EN REGISTRO
                    if (registro) ...[
                      const SizedBox(height: 8),

                      const Text(
                        'La contraseña debe tener al menos '
                        '6 caracteres.',
                        style: TextStyle(
                          fontSize: 12,
                          color: EcoColors.muted,
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: comunaSeleccionada,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Comuna',
                          prefixIcon: Icon(
                            Icons.location_city_outlined,
                          ),
                          border: OutlineInputBorder(),
                        ),

                        hint: const Text(
                          'Selecciona tu comuna',
                        ),

                        items: comunas.map((comuna) {
                          return DropdownMenuItem<String>(
                            value: comuna,
                            child: Text(comuna),
                          );
                        }).toList(),

                        onChanged: procesando
                            ? null
                            : (valor) {
                                setState(() {
                                  comunaSeleccionada = valor;
                                });
                              },

                        validator: (valor) {
                          if (valor == null ||
                              valor.isEmpty) {
                            return 'Selecciona tu comuna.';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 25),

                    // BOTÓN PRINCIPAL
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            procesando ? null : enviar,
                        icon: procesando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                registro
                                    ? Icons.person_add_rounded
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          procesando
                              ? 'Procesando...'
                              : registro
                                  ? 'Crear mi cuenta'
                                  : 'Ingresar',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CAMBIAR DE LOGIN A REGISTRO
                    TextButton(
                      onPressed:
                          procesando ? null : cambiarModo,
                      child: Text(
                        registro
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
    );
  }
}
