import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': username.trim(),
        // Keep the previous schema's unique username trigger from colliding.
        'username':
            '${username.trim()}_${DateTime.now().microsecondsSinceEpoch}',
      },
    );
  }

  Future<void> signOut() async {
    await PushNotificationService.instance.unregisterCurrentUser();
    await _client.auth.signOut();
  }
}
