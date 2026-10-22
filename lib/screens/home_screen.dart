import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/daily_notification_service.dart';
import '../widgets/open_status_banner.dart';
import 'chat_screen.dart';
import 'gallery_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Map<String, dynamic>> _profile;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    _profile = Supabase.instance.client
        .from('profiles')
        .select('id, username, role')
        .eq('id', userId)
        .single();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNotification());
  }

  Future<void> _scheduleNotification() async {
    try {
      final scheduled =
          await DailyNotificationService.instance.scheduleDailyAtEight();
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa los permisos de notificaciones y alarmas exactas.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo programar el aviso: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService(Supabase.instance.client);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbería YASSER'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
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
          return snapshot.data!['role'] == 'barber'
              ? const _BarberHome()
              : const _ClientHome();
        },
      ),
    );
  }
}

class _ClientHome extends StatelessWidget {
  const _ClientHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const OpenStatusBanner(),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Galería de cortes'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const GalleryScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Mi historial'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.chat),
          title: const Text('Chat con YASSER'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
          ),
        ),
      ],
    );
  }
}

class _BarberHome extends StatelessWidget {
  const _BarberHome();

  @override
  Widget build(BuildContext context) {
    final clients = Supabase.instance.client
        .from('profiles')
        .select('id, username')
        .eq('role', 'client')
        .order('username');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: clients,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('No se pudieron cargar los clientes: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const Center(child: Text('Todavía no hay clientes registrados.'));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final client = rows[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(client['username'] as String),
              subtitle: const Text('Abrir chat privado'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    partnerId: client['id'] as String,
                    partnerName: client['username'] as String,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
