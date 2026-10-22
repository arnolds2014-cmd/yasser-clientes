import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _auth = AuthService(Supabase.instance.client);
  bool _registering = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_registering) {
        final response = await _auth.signUp(
          email: _email.text,
          password: _password.text,
          username: _username.text,
        );
        if (response.session == null && mounted) {
          setState(() {
            _notice =
                'Cuenta creada. Revisa tu correo para confirmar la dirección antes de iniciar sesión.';
          });
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo completar la operación: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YASSER')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_registering)
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Escribe un usuario'
                            : null,
                  ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Escribe un correo válido'
                      : null,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (value) => value == null || value.length < 6
                      ? 'Usa al menos 6 caracteres'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy
                      ? 'Procesando…'
                      : _registering
                          ? 'Crear cuenta'
                          : 'Iniciar sesión'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _registering = !_registering;
                            _error = null;
                            _notice = null;
                          }),
                  child: Text(_registering
                      ? 'Ya tengo cuenta'
                      : 'Crear cuenta de cliente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
