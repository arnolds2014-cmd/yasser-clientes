import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _channelId = 'yasser_messages';
  static const _channelName = 'Mensajes del chat';

  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Avisos de mensajes nuevos en el chat de YASSER',
      importance: Importance.high,
    );
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initializationSettings);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.requestPermission();
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      _saveTokenForCurrentUser,
    );
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session != null) unawaited(_registerCurrentUser());
    });
    await _registerCurrentUser();
  }

  Future<void> _registerCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveTokenForCurrentUser(token);
  }

  Future<void> _saveTokenForCurrentUser(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('yasser_push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> unregisterCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client
        .from('yasser_push_tokens')
        .delete()
        .eq('user_id', user.id)
        .eq('token', token);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      notification.title ?? 'Barbería YASSER',
      notification.body ?? 'Tienes un mensaje nuevo.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Avisos de mensajes nuevos en el chat de YASSER',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
