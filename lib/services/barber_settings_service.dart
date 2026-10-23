import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BarberHours {
  const BarberHours({required this.opensAt, required this.closesAt});

  final TimeOfDay opensAt;
  final TimeOfDay closesAt;

  factory BarberHours.fromRow(Map<String, dynamic> row) {
    return BarberHours(
      opensAt: _parseTime(row['opening_time'] as String),
      closesAt: _parseTime(row['closing_time'] as String),
    );
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      throw FormatException('Formato de horario inesperado: $value');
    }
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool isOpenAt(DateTime time) {
    final nowMinutes = time.hour * 60 + time.minute;
    final openingMinutes = opensAt.hour * 60 + opensAt.minute;
    final closingMinutes = closesAt.hour * 60 + closesAt.minute;
    if (openingMinutes == closingMinutes) return false;
    if (openingMinutes < closingMinutes) {
      return nowMinutes >= openingMinutes && nowMinutes < closingMinutes;
    }
    return nowMinutes >= openingMinutes || nowMinutes < closingMinutes;
  }

  static String _formatTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';
  }

  Map<String, String> toUpdate() => {
    'opening_time': _formatTime(opensAt),
    'closing_time': _formatTime(closesAt),
  };
}

class BarberSettingsService {
  BarberSettingsService(this._client);

  final SupabaseClient _client;

  Stream<BarberHours> watchHours() {
    return _client
        .from('yasser_barber_settings')
        .stream(primaryKey: ['singleton'])
        .map((rows) {
          if (rows.isEmpty) {
            throw StateError('No está configurado el horario de la barbería.');
          }
          return BarberHours.fromRow(rows.first);
        });
  }

  Future<void> updateHours(BarberHours hours) async {
    if (hours.opensAt.hour == hours.closesAt.hour &&
        hours.opensAt.minute == hours.closesAt.minute) {
      throw ArgumentError('La apertura y el cierre no pueden ser iguales.');
    }
    final response = await _client
        .from('yasser_barber_settings')
        .update(hours.toUpdate())
        .eq('singleton', true)
        .select('singleton');
    if (response.isEmpty) {
      throw StateError('No se guardó el horario; confirma que seas el barbero.');
    }
  }
}
