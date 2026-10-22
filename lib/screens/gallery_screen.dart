import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/chat_service.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static const _cuts = [
    (id: 'fade-01', name: 'Fade clásico', image: 'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900'),
    (id: 'crop-02', name: 'Crop texturizado', image: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900'),
  ];

  Future<void> _requestCut(BuildContext context, String id, String image) async {
    try {
      await ChatService(
        Supabase.instance.client,
        partnerId: AppConfig.barberId,
      )
          .send('Quiero este corte ($id): $image', kind: 'cut_reference');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referencia enviada al chat privado')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la referencia: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galería de cortes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final cut in _cuts)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.network(
                    cut.image,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 220, child: Icon(Icons.content_cut)),
                  ),
                  ListTile(
                    title: Text(cut.name),
                    subtitle: Text('ID: ${cut.id}'),
                    trailing: FilledButton(
                      onPressed: () => _requestCut(context, cut.id, cut.image),
                      child: const Text('Quiero este corte'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
