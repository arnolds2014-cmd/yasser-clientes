import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'barber_hours_screen.dart';
import 'gallery_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  late final Future<Map<String, dynamic>> _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _profile = Supabase.instance.client
        .from('yasser_profiles')
        .select('username')
        .eq('id', userId ?? '')
        .single();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere una sesión activa.')),
      );
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un nombre.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('yasser_profiles')
          .update({'username': name})
          .eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el perfil: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo cargar el perfil: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_name.text.isEmpty) {
            _name.text = snapshot.data!['username'] as String;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (Supabase.instance.client.auth.currentUser?.id ==
                  AppConfig.barberId) ...[
                ListTile(
                  leading: const Icon(Icons.schedule, size: 30),
                  title: const Text(
                    'Editar horario de la barbería',
                    style: TextStyle(fontSize: 19),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BarberHoursScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, size: 30),
                  title: const Text(
                    'Administrar galería',
                    style: TextStyle(fontSize: 19),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const GalleryScreen(),
                    ),
                  ),
                ),
                const Divider(height: 28),
              ],
              TextField(
                controller: _name,
                maxLength: 60,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Nombre visible',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar perfil'),
              ),
            ],
          );
        },
      ),
    );
  }
}
