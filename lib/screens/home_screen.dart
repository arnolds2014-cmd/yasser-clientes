import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/chat_service.dart';
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
  StreamSubscription<List<Map<String, dynamic>>>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNotification());
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('id, username, role')
        .eq('id', userId)
        .single();
    if (profile['role'] == 'client') _connectClientChat();
    return profile;
  }

  void _connectClientChat() {
    _chatSubscription = ChatService(
      Supabase.instance.client,
      partnerId: AppConfig.barberId,
    ).watchConversation().listen(
      (_) {},
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo conectar al chat: $error')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    final subscription = _chatSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
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

class _BarberHome extends StatefulWidget {
  const _BarberHome();

  @override
  State<_BarberHome> createState() => _BarberHomeState();
}

class _BarberHomeState extends State<_BarberHome> {
  late final Stream<List<Map<String, dynamic>>> _clients;

  @override
  void initState() {
    super.initState();
    _clients = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('username')
        .map((profiles) =>
            profiles.where((profile) => profile['role'] == 'client').toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _clients,
      builder: (context, clientsSnapshot) {
        if (clientsSnapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar los clientes: ${clientsSnapshot.error}',
            ),
          );
        }
        if (!clientsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = clientsSnapshot.data!;
        if (rows.isEmpty) {
          return const Center(
            child: Text('Todavía no hay clientes registrados.'),
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final client = rows[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(client['username'] as String),
              subtitle: const Text('Abrir chat privado'),
              trailing: IconButton(
                tooltip: 'Ver historial de cortes',
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(
                      clientId: client['id'] as String,
                    ),
                  ),
                ),
              ),
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
