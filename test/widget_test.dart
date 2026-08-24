import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/main.dart';
import 'package:tabangnow_flutter/screens/auth_gate.dart';

void main() {
  testWidgets('TabangNow production auth gate loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TabangNowApp());

    expect(find.byType(AuthGate), findsOneWidget);
  });
}
