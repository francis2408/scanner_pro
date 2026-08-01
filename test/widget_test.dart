import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/main.dart';

void main() {
  testWidgets('Universal Scanner App renders dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UniversalScannerApp());

    expect(find.text('Universal Scanner'), findsOneWidget);
    expect(find.text('Android & iOS Cross-Platform SDK'), findsOneWidget);
  });
}
