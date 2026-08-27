import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity Logs is live in ModuleRegistry and HomeScreen', () {
    final registry = File('lib/core/module_registry.dart').readAsStringSync();

    final start = registry.indexOf('id: AppModuleId.activityLogs,');

    expect(start, greaterThanOrEqualTo(0));

    final next = registry.indexOf('AppModuleDefinition(', start + 1);

    final block = registry.substring(start, next >= 0 ? next : registry.length);

    expect(block, contains('mobileImplemented: true'));

    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    for (final marker in <String>[
      "import 'activity_logs_screen.dart';",
      "import '../widgets/global_account_footer.dart';",
      '_HomeModule.activityLogs',
      'AppModuleId.activityLogs => _HomeModule.activityLogs,',
      '_HomeModule.activityLogs => AppModuleId.activityLogs,',
      'return ActivityLogsScreen(',
      'GlobalAccountFooter(',
      'GlobalThemeButton(',
      'GlobalNotificationBell(',
      'ModuleRegistry.canAccess(',
      'scaffoldState.isDrawerOpen',
    ]) {
      expect(
        home,
        contains(marker),
        reason: 'Missing Activity Logs/global marker: $marker',
      );
    }

    expect(home, isNot(contains("tooltip: 'Refresh'")));
  });

  test('Activity Logs stays Admin-only in Flutter capabilities', () {
    final capabilities = File(
      'lib/core/app_capabilities.dart',
    ).readAsStringSync();

    final adminStart = capabilities.indexOf('case AppRole.admin:');

    final officialStart = capabilities.indexOf('case AppRole.official:');

    final tanodStart = capabilities.indexOf('case AppRole.tanod:');

    expect(adminStart, greaterThanOrEqualTo(0));

    expect(
      capabilities.substring(adminStart, officialStart),
      contains('AppCapability.viewActivityLogs'),
    );

    expect(
      capabilities.substring(officialStart, tanodStart),
      isNot(contains('AppCapability.viewActivityLogs')),
    );
  });

  test(
    'Activity Logs screen replicates website filters and rows',
    () {
      final screen = File(
        'lib/screens/activity_logs_screen.dart',
      ).readAsStringSync();

      for (final marker in <String>[
        'SECURITY AUDIT TRAIL',
        "'Activity Logs'",
        'Actor, event, description, route, or IP',
        'All categories',
        'All events',
        'All actors',
        'Date from',
        'Date to',
        '10',
        '25',
        '50',
        '100',
        'matching records',
        'System / Unknown',
        'No actor role',
        'View activity log',
        'No activity logs matched the selected filters.',
        'Clear the filters or choose a wider date range.',
        '_deleteAllPermanently',
      ]) {
        expect(
          screen,
          contains(marker),
          reason: 'Missing Activity Logs index marker: $marker',
        );
      }
    },
  );

  test(
    'Activity Log detail includes exact audit sections and metadata redaction notice',
    () {
      final detail = File(
        'lib/screens/activity_log_detail_screen.dart',
      ).readAsStringSync();

      for (final marker in <String>[
        'READ-ONLY AUDIT RECORD',
        'Event information',
        'Actor and target',
        'Request information',
        'Metadata',
        'Log ID',
        'Recorded',
        'Target user',
        'IP address',
        'User agent',
        'Sensitive keys are redacted',
        'stored as snapshots',
      ]) {
        expect(
          detail,
          contains(marker),
          reason: 'Missing Activity Log detail marker: $marker',
        );
      }
    },
  );

  test(
    'Activity Logs keeps IP audit data without the development explanation box',
    () {
      final list = File(
        'lib/screens/activity_logs_screen.dart',
      ).readAsStringSync();

      final detail = File(
        'lib/screens/activity_log_detail_screen.dart',
      ).readAsStringSync();

      expect(
        list,
        isNot(contains('IP addresses are request-derived, not static.')),
        reason: 'The removed IP explanation notice must not return.',
      );

      expect(
        list,
        isNot(contains('class _IpCaptureNotice extends StatelessWidget')),
        reason: 'The removed IP explanation widget must not return.',
      );

      for (final marker in <String>[
        "log['ip_address']",
        "log['ip_context']",
        'LOCAL BRIDGE',
        'Actor, event, description, route, or IP',
      ]) {
        expect(
          list,
          contains(marker),
          reason: 'Missing Activity Logs IP functionality marker: $marker',
        );
      }

      expect(
        detail,
        contains('IP address'),
        reason: 'Activity Log detail must continue to show the stored IP.',
      );
    },
  );

  test(
    'Global account footer replicates clickable profile menu with icons and dev session action',
    () {
      final footer = File(
        'lib/widgets/global_account_footer.dart',
      ).readAsStringSync();

      for (final marker in <String>[
        'GlobalAccountFooter',
        'Icons.more_horiz_rounded',
        'Icons.person_outline_rounded',
        "'Profile'",
        'Icons.restart_alt_rounded',
        'Restart Dev Session',
      ]) {
        expect(
          footer,
          contains(marker),
          reason: 'Missing global account footer marker: $marker',
        );
      }

      final home = File('lib/screens/home_screen.dart').readAsStringSync();

      expect(home, contains('_openAccountProfile'));

      expect(home, isNot(contains('UserManagementDetailScreen(')));

      expect(home, contains('CurrentAccountProfileScreen('));
    },
  );

  test('Development login bypass remains active', () {
    final gate = File('lib/screens/dev_session_gate.dart');

    if (!gate.existsSync()) {
      return;
    }

    final text = gate.readAsStringSync();

    expect(text, isNot(contains('return const LoginScreen()')));

    expect(text, isNot(contains('Open Login')));
  });
}
