import 'package:flutter_test/flutter_test.dart';
import 'package:alijaya_network_suite/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AlijayaNetSuiteApp());
    expect(find.byType(AlijayaNetSuiteApp), findsOneWidget);
  });
}
