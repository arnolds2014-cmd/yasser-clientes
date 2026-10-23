import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/chat_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const _bucket = 'yasser-gallery';
  final _title = TextEditingController();
  final _picker = ImagePicker();
  late final SupabaseClient _client;
  late final Stream<List<Map<String, dynamic>>> _items;
  bool _busy = false;

  bool get _isBarber =>
      _client.auth.currentUser?.id == AppConfig.barberId;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _items = _client
        .from('yasser_gallery_items')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    final userId = _client.auth.currentUser?.id;
    if (userId != AppConfig.barberId) return;
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (selected == null || !mounted) return;

    setState(() => _busy = true);
    String? uploadedPath;
    try {
      final extension = selected.name.contains('.')
          ? selected.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      uploadedPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage.from(_bucket).uploadBinary(
        uploadedPath,
        await selected.readAsBytes(),
        fileOptions: FileOptions(contentType: contentType),
      );
      final title = _title.text.trim().isEmpty
          ? selected.name
          : _title.text.trim();
      await _client.from('yasser_gallery_items').insert({
        'title': title,
        'storage_path': uploadedPath,
      });
      _title.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen agregada a la galería.')),
        );
      }
    } catch (error) {
      var message = 'No se pudo subir la imagen: $error';
      if (uploadedPath != null) {
        try {
          await _client.storage.from(_bucket).remove([uploadedPath]);
        } catch (cleanupError) {
          message += '\nNo se pudo limpiar el archivo subido: $cleanupError';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> item) async {
    if (!_isBarber) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar imagen'),
        content: const Text('¿Quieres quitar esta foto de la galería?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _client
          .from('yasser_gallery_items')
          .delete()
          .eq('id', item['id'] as String);
      await _client.storage.from(_bucket).remove([
        item['storage_path'] as String,
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo quitar la imagen: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCut(Map<String, dynamic> item, String imageUrl) async {
    try {
      await ChatService(_client, partnerId: AppConfig.barberId).send(
        'Quiero este corte (${item['title']}): $imageUrl',
        kind: 'cut_reference',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referencia enviada al chat privado')),
        );
      }
    } catch (error) {
      if (mounted) {
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
      body: Column(
        children: [
          if (_isBarber)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del corte (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Subir foto',
                    onPressed: _busy ? null : _uploadImage,
                    icon: const Icon(Icons.add_photo_alternate, size: 28),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudo cargar la galería: ${snapshot.error}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      _isBarber
                          ? 'Sube las fotos de tus cortes aquí.'
                          : 'Todavía no hay fotos en la galería.',
                      style: const TextStyle(fontSize: 18),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    final imageUrl = _client.storage
                        .from(_bucket)
                        .getPublicUrl(item['storage_path'] as String);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.network(
                            imageUrl,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 260,
                                  child: Center(
                                    child: Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_isBarber)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _busy ? null : () => _deleteImage(item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Quitar foto'),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: FilledButton.icon(
                                onPressed: () => _requestCut(item, imageUrl),
                                icon: const Icon(Icons.chat),
                                label: const Text('Quiero este corte'),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
