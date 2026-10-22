import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService(this._client, {required this.partnerId});

  final SupabaseClient _client;
  final String partnerId;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Se requiere una sesión activa.');
    return id;
  }

  Stream<List<Map<String, dynamic>>> watchConversation() {
    final userId = _userId;
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows
            .where((row) =>
                (row['sender_id'] == userId &&
                    row['recipient_id'] == partnerId) ||
                (row['sender_id'] == partnerId &&
                    row['recipient_id'] == userId))
            .toList());
  }

  Future<void> send(String text, {String kind = 'text'}) async {
    final body = text.trim();
    if (body.isEmpty) return;
    await _client.from('messages').insert({
      'sender_id': _userId,
      'recipient_id': partnerId,
      'body': body,
      'kind': kind,
    });
  }
}
