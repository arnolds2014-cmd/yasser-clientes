import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/barber_settings_service.dart';

class BarberHoursScreen extends StatefulWidget {
  const BarberHoursScreen({super.key});

  @override
  State<BarberHoursScreen> createState() => _BarberHoursScreenState();
}

class _BarberHoursScreenState extends State<BarberHoursScreen> {
  late final BarberSettingsService _settings;
  TimeOfDay? _opensAt;
  TimeOfDay? _closesAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = BarberSettingsService(Supabase.instance.client);
  }

  Future<void> _chooseTime({required bool opening}) async {
    final current = opening ? _opensAt : _closesAt;
    final selected = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        _opensAt = selected;
      } else {
        _closesAt = selected;
      }
    });
  }

  Future<void> _save() async {
    final opensAt = _opensAt;
    final closesAt = _closesAt;
    if (opensAt == null || closesAt == null) return;
    setState(() => _saving = true);
    try {
      await _settings.updateHours(
        BarberHours(opensAt: opensAt, closesAt: closesAt),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horario guardado; el banner se actualizará.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el horario: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horario de la barbería')),
      body: StreamBuilder<BarberHours>(
        stream: _settings.watchHours(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo cargar el horario: ${snapshot.error}'),
            );
          }
          final saved = snapshot.data;
          if (saved == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _opensAt ??= saved.opensAt;
          _closesAt ??= saved.closesAt;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Los clientes verán el banner actualizado al guardar.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Apertura', style: TextStyle(fontSize: 20)),
                subtitle: Text(
                  _opensAt!.format(context),
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: const Icon(Icons.schedule, size: 30),
                onTap: () => _chooseTime(opening: true),
              ),
              ListTile(
                title: const Text('Cierre', style: TextStyle(fontSize: 20)),
                subtitle: Text(
                  _closesAt!.format(context),
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: const Icon(Icons.schedule, size: 30),
                onTap: () => _chooseTime(opening: false),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Guardando…' : 'Guardar horario'),
              ),
            ],
          );
        },
      ),
    );
  }
}
