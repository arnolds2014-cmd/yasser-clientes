import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yasser_barber/services/barber_settings_service.dart';

void main() {
  test('uses editable opening and closing times for status', () {
    const hours = BarberHours(
      opensAt: TimeOfDay(hour: 13, minute: 0),
      closesAt: TimeOfDay(hour: 21, minute: 0),
    );

    expect(hours.isOpenAt(DateTime(2026, 1, 1, 12, 59)), isFalse);
    expect(hours.isOpenAt(DateTime(2026, 1, 1, 13, 0)), isTrue);
    expect(hours.isOpenAt(DateTime(2026, 1, 1, 20, 59)), isTrue);
    expect(hours.isOpenAt(DateTime(2026, 1, 1, 21, 0)), isFalse);
  });

  test('supports business hours that pass midnight', () {
    const hours = BarberHours(
      opensAt: TimeOfDay(hour: 18, minute: 0),
      closesAt: TimeOfDay(hour: 2, minute: 0),
    );

    expect(hours.isOpenAt(DateTime(2026, 1, 1, 18, 0)), isTrue);
    expect(hours.isOpenAt(DateTime(2026, 1, 2, 1, 59)), isTrue);
    expect(hours.isOpenAt(DateTime(2026, 1, 2, 2, 0)), isFalse);
    expect(hours.isOpenAt(DateTime(2026, 1, 2, 12, 0)), isFalse);
  });
}
