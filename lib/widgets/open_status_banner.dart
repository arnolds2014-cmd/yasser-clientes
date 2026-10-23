import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/barber_settings_service.dart';

class OpenStatusBanner extends StatefulWidget {
  const OpenStatusBanner({super.key, DateTime? now}) : _now = now;

  final DateTime? _now;

  @override
  State<OpenStatusBanner> createState() => _OpenStatusBannerState();
}

class _OpenStatusBannerState extends State<OpenStatusBanner> {
  Timer? _timer;
  late final Stream<BarberHours>? _hours;

  @override
  void initState() {
    super.initState();
    _hours = widget._now == null
        ? BarberSettingsService(
            Supabase.instance.client,
          ).watchHours()
        : null;
    if (widget._now == null) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    final now = DateTime.now();
    final untilNextMinute = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(untilNextMinute, () {
      if (!mounted) return;
      setState(() {});
      _scheduleRefresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = widget._now ?? DateTime.now();
    final hoursStream = _hours;
    if (hoursStream == null) {
      final isOpen = time.hour >= 8 && time.hour < 20;
      return _banner(isOpen ? '🟢 ABIERTO' : '🔴 CERRADO', isOpen);
    }
    return StreamBuilder<BarberHours>(
      stream: hoursStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _banner('HORARIO NO DISPONIBLE', false);
        }
        final hours = snapshot.data;
        if (hours == null) return _banner('CARGANDO HORARIO…', false);
        final isOpen = hours.isOpenAt(time);
        return _banner(isOpen ? '🟢 ABIERTO' : '🔴 CERRADO', isOpen);
      },
    );
  }

  Widget _banner(String text, bool isOpen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
