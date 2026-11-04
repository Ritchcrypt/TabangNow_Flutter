import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/widgets/admin_mfa_code_prompt.dart';

void main() {
  testWidgets('All-role MFA prompt supports cancel and does not retain a controller', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async { received = await requestAdminMfaCode(context); },
        child: const Text('Open MFA'),
      ))),
    ));
    await tester.tap(find.text('Open MFA'));
    await tester.pumpAndSettle();
    expect(find.text('Account verification'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(received, isNull);
  });
}
