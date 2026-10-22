import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.clientId});

  final String? clientId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _specifications = TextEditingController();
  late Future<List<Map<String, dynamic>>> _entries;
  bool _saving = false;
  String? _error;

  String get _clientId =>
      widget.clientId ?? Supabase.instance.client.auth.currentUser!.id;

  bool get _barberEditing => widget.clientId != null;

  Future<List<Map<String, dynamic>>> _loadEntries() {
    return Supabase.instance.client
        .from('yasser_haircut_history')
        .select('id, specifications, created_at')
        .eq('client_id', _clientId)
        .order('created_at', ascending: false);
  }

  @override
  void initState() {
    super.initState();
    _entries = _loadEntries();
  }

  @override
  void dispose() {
    _specifications.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final specifications = _specifications.text.trim();
    if (specifications.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('yasser_haircut_history').insert({
        'client_id': _clientId,
        'specifications': specifications,
      });
      if (!mounted) return;
      _specifications.clear();
      setState(() => _entries = _loadEntries());
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el historial: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cortes')),
      body: Column(
        children: [
          if (_barberEditing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _specifications,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Especificaciones del corte',
                      hintText: 'Navaja, productos, técnica…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _addEntry,
                      icon: const Icon(Icons.save),
                      label: Text(_saving ? 'Guardando…' : 'Guardar corte'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar el historial: ${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Todavía no hay cortes registrados.'),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.content_cut),
                    title: Text(entries[index]['specifications'] as String),
                    subtitle: Text(entries[index]['created_at'] as String),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
