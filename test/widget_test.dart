import 'package:flutter_test/flutter_test.dart';
import 'package:yasser_barber/main.dart';

void main() {
  testWidgets('explains the required backend configuration', (tester) async {
    await tester.pumpWidget(const ConfigurationRequiredApp());

    expect(
      find.textContaining('SUPABASE_PUBLISHABLE_KEY'),
      findsOneWidget,
    );
  });
}
