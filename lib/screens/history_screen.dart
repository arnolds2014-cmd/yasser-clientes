import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cortes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('haircut_history')
            .select('id, specifications, created_at')
            .eq('client_id', userId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar el historial: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('Todavía no hay cortes registrados.'));
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
    );
  }
}
