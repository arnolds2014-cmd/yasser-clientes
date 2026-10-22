import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yasser_barber/widgets/open_status_banner.dart';

void main() {
  testWidgets('shows closed before 08:00 and at 20:00', (tester) async {
    for (final time in [
      DateTime(2026, 1, 1, 7, 59),
      DateTime(2026, 1, 1, 20, 0),
    ]) {
      await tester.pumpWidget(MaterialApp(home: OpenStatusBanner(now: time)));
      expect(find.text('🔴 CERRADO'), findsOneWidget);
    }
  });

  testWidgets('shows open from 08:00 until before 20:00', (tester) async {
    for (final time in [
      DateTime(2026, 1, 1, 8, 0),
      DateTime(2026, 1, 1, 19, 59),
    ]) {
      await tester.pumpWidget(MaterialApp(home: OpenStatusBanner(now: time)));
      expect(find.text('🟢 ABIERTO'), findsOneWidget);
    }
  });
}
