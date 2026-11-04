import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/auth_service.dart';
import 'package:tabangnow_flutter/services/dao_news_service.dart';
import 'package:tabangnow_flutter/widgets/dao_news_manager.dart';

class _FakeDaoNewsService extends DaoNewsService {
  _FakeDaoNewsService() : super(authService: AuthService());

  String? savedAction;
  String? savedId;
  String? savedUrl;

  @override
  Future<Map<String, dynamic>> manage() async {
    final now = DateTime.now().toUtc();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return <String, dynamic>{
      'topics': <String>['Health and services', 'Local government'],
      'audit': <Map<String, dynamic>>[],
      'entries': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '11111111-1111-4111-8111-111111111111',
          'url': 'https://www.pna.gov.ph/articles/123456',
          'topic': 'Health and services',
          'published': date,
          'approved': true,
          'trusted': true,
        },
      ],
    };
  }

  @override
  Future<void> act(String action, {
    String? id,
    String? url,
    String? topic,
    String? published,
    bool confirmed = false,
  }) async {
    savedAction = action;
    savedId = id;
    savedUrl = url;
  }
}

Future<void> _showManager(WidgetTester tester, _FakeDaoNewsService service) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DaoNewsManager(service: service, onChanged: () {}),
      ),
    ),
  ));
  await tester.tap(find.text('Manage external news links (Admin only)'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Edit').first);
  await tester.tap(find.text('Edit').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('news dialog is responsive and cancel disposes route safely', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeDaoNewsService();
    await _showManager(tester, service);

    expect(find.text('Edit news link'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.getSize(find.byType(AlertDialog)).width, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit news link'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('news dialog save returns values and closes without lifecycle error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeDaoNewsService();
    await _showManager(tester, service);

    final checks = find.byType(CheckboxListTile);
    expect(checks, findsNWidgets(2));
    await tester.ensureVisible(checks.at(0));
    await tester.tap(checks.at(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(checks.at(1));
    await tester.tap(checks.at(1));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save.onPressed, isNotNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.savedAction, 'edit');
    expect(service.savedId, '11111111-1111-4111-8111-111111111111');
    expect(service.savedUrl, 'https://www.pna.gov.ph/articles/123456');
    expect(tester.takeException(), isNull);
  });
}
