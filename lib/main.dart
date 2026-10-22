import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/daily_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const ConfigurationRequiredApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  await Firebase.initializeApp();
  await DailyNotificationService.instance.initialize();
  runApp(const YasserApp());
}

class YasserApp extends StatelessWidget {
  const YasserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YASSER',
      theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session =
              snapshot.data?.session ??
              Supabase.instance.client.auth.currentSession;
          return session == null ? const AuthScreen() : const HomeScreen();
        },
      ),
    );
  }
}

class ConfigurationRequiredApp extends StatelessWidget {
  const ConfigurationRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YASSER',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Falta configurar SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY y BARBER_ID '
              'al compilar la aplicación. Consulta el README.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
