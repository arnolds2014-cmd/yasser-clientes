import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/chat_service.dart';
import '../widgets/image_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.partnerId = AppConfig.barberId,
    this.partnerName = 'YASSER',
  });

  final String partnerId;
  final String partnerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _messagesController = ScrollController();
  late final ChatService _chat;
  late final Stream<List<Map<String, dynamic>>> _messages;
  String? _error;
  String? _latestMessageId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _chat = ChatService(Supabase.instance.client, partnerId: widget.partnerId);
    _messages = _chat.watchConversation();
  }

  @override
  void dispose() {
    _input.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  void _keepLatestMessageVisible(List<Map<String, dynamic>> messages) {
    final latestMessageId = messages.isEmpty
        ? null
        : messages.first['id']?.toString();
    if (latestMessageId == _latestMessageId) return;
    _latestMessageId = latestMessageId;
    if (latestMessageId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesController.hasClients) return;
      _messagesController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    if (_sending || _input.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _chat.send(_input.text);
      if (!mounted) return;
      _input.clear();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo enviar el mensaje: $error');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat con ${widget.partnerName}')),
      body: ImageBackground(
        asset: 'assets/images/chat_background.jpg',
        lightOverlay: 0.88,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar mensajes: ${snapshot.error}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  _keepLatestMessageVisible(messages);
                  return ListView.builder(
                    controller: _messagesController,
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine =
                          message['sender_id'] ==
                          Supabase.instance.client.auth.currentUser?.id;
                      return Align(
                        key: ValueKey(message['id']),
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message['body'] as String,
                            style: const TextStyle(fontSize: 19, height: 1.3),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 19),
                        decoration: InputDecoration(
                          hintText: 'Escribe tu mensaje',
                          hintStyle: const TextStyle(fontSize: 18),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Enviar mensaje',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, size: 28),
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
