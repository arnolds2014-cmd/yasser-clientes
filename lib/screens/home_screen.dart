import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/barber_settings_service.dart';
import '../services/chat_service.dart';
import '../services/daily_notification_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/image_background.dart';
import '../widgets/open_status_banner.dart';
import 'barber_hours_screen.dart';
import 'chat_screen.dart';
import 'gallery_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Map<String, dynamic>> _profile;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSubscription;
  StreamSubscription<BarberHours>? _hoursSubscription;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _watchOpeningHours();
        _initializePushNotifications();
      },
    );
  }

  Future<void> _initializePushNotifications() async {
    try {
      await PushNotificationService.instance.initialize();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron activar las notificaciones: $error'),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final profile = await Supabase.instance.client
        .from('yasser_profiles')
        .select('id, username')
        .eq('id', userId)
        .single();
    if (userId != AppConfig.barberId) _connectClientChat();
    return profile;
  }

  void _watchOpeningHours() {
    _hoursSubscription = BarberSettingsService(
      Supabase.instance.client,
    ).watchHours().listen(
      (hours) => _scheduleOpeningNotification(hours.opensAt),
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cargar el horario: $error')),
          );
        }
      },
    );
  }

  void _connectClientChat() {
    _chatSubscription =
        ChatService(
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
    final hoursSubscription = _hoursSubscription;
    if (hoursSubscription != null) unawaited(hoursSubscription.cancel());
    super.dispose();
  }

  Future<void> _scheduleOpeningNotification(TimeOfDay openingTime) async {
    try {
      final scheduled = await DailyNotificationService.instance
          .scheduleDailyAt(openingTime);
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa los permisos de notificaciones y alarmas exactas.',
            ),
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
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ),
            icon: const Icon(Icons.person),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ImageBackground(
        asset: 'assets/images/home_background.jpg',
        child: FutureBuilder<Map<String, dynamic>>(
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
            return Supabase.instance.client.auth.currentUser?.id ==
                    AppConfig.barberId
                ? const _BarberHome()
                : const _ClientHome();
          },
        ),
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
          leading: const Icon(Icons.chat),
          title: const Text('Chat con YASSER', style: TextStyle(fontSize: 20)),
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
        .from('yasser_profiles')
        .stream(primaryKey: ['id'])
        .order('username')
        .map(
          (profiles) => profiles
              .where((profile) => profile['id'] != AppConfig.barberId)
              .toList(),
        );
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
        return ListView(
          children: [
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Todavía no hay clientes registrados.',
                  style: TextStyle(fontSize: 18),
                ),
              )
            else
              for (final client in rows)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    client['username'] as String,
                    style: const TextStyle(fontSize: 20),
                  ),
                  subtitle: const Text(
                    'Abrir chat privado',
                    style: TextStyle(fontSize: 16),
                  ),
                  trailing: IconButton(
                    tooltip: 'Ver historial de cortes',
                    icon: const Icon(Icons.history, size: 28),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HistoryScreen(clientId: client['id'] as String),
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
                ),
          ],
        );
      },
    );
  }
}
