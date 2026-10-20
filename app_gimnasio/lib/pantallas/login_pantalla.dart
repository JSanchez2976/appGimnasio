import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _esRegistro = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (_esRegistro) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      }
      // Si va bien, PuertaAutenticacion cambia de pantalla sola.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _traducirError(e.code));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _traducirError(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      default:
        return 'Algo ha fallado ($codigo). Inténtalo de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Peso y Calorías',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _esRegistro ? 'Crea tu cuenta' : 'Inicia sesión',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || !v.contains('@')) {
                          return 'Escribe un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviar,
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_esRegistro ? 'Crear cuenta' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                                _esRegistro = !_esRegistro;
                                _error = null;
                              }),
                      child: Text(
                        _esRegistro
                            ? 'Ya tengo cuenta, iniciar sesión'
                            : 'No tengo cuenta, registrarme',
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