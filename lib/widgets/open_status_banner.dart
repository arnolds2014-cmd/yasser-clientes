import 'dart:async';

import 'package:flutter/material.dart';

class OpenStatusBanner extends StatefulWidget {
  const OpenStatusBanner({super.key, DateTime? now}) : _now = now;

  final DateTime? _now;

  @override
  State<OpenStatusBanner> createState() => _OpenStatusBannerState();
}

class _OpenStatusBannerState extends State<OpenStatusBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
    final isOpen = time.hour >= 8 && time.hour < 20;
    final color = isOpen ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: color,
      child: Text(
        isOpen ? '🟢 ABIERTO' : '🔴 CERRADO',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
