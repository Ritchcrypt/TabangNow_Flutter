import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tanod Tasks is live in ModuleRegistry', () {
    final registry = File('lib/core/module_registry.dart').readAsStringSync();

    final start = registry.indexOf('id: AppModuleId.tanodTasks,');

    expect(start, greaterThanOrEqualTo(0));

    final next = registry.indexOf('AppModuleDefinition(', start + 1);

    final block = registry.substring(start, next >= 0 ? next : registry.length);

    expect(block, contains("defaultLabel: 'Tanod Tasks'"));
    expect(block, contains("websiteGlyph: '📋'"));
    expect(block, contains('mobileImplemented: true'));
  });

  test('Tanod Task assignments use the existing Code Red alert', () {
    final source = File(
      'lib/services/background_notification_alert_service.dart',
    ).readAsStringSync();

    final start = source.indexOf('const codeRedTypes = <String>{');
    expect(start, greaterThanOrEqualTo(0));

    final end = source.indexOf('};', start);
    expect(end, greaterThan(start));

    final codeRedTypes = source.substring(start, end);

    expect(codeRedTypes, contains("'tanod_task'"));
    expect(codeRedTypes, contains("'tanod_task_assigned'"));
    expect(codeRedTypes, contains("'task_assigned'"));

    expect(source, contains('tabangnow_notification_v4'));
    expect(source, contains('_criticalVibrationPattern'));
  });

  test('HomeScreen connects Tanod Tasks globally', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    for (final marker in <String>[
      "import 'tanod_tasks_screen.dart';",
      '_HomeModule.tanodTasks',
      'AppModuleId.tanodTasks',
      'TanodTasksScreen(',
      'GlobalThemeButton(',
      'GlobalNotificationBell(',
      'scaffoldState.isDrawerOpen',
    ]) {
      expect(home, contains(marker), reason: 'Missing $marker');
    }

    expect(home, isNot(contains("_showPendingModule('Tanod Tasks')")));
  });

  test('Tanod Tasks screen mirrors admin/tanod workflows', () {
    final screen = File(
      'lib/screens/tanod_tasks_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      'Create Tanod Task',
      'My Assigned Tasks',
      'Create Task',
      'Accept',
      'Decline',
      'Close Task',
      'Cancel Task',
      'Tanod Responses',
      'Accepted',
      'Declined',
      'Pending',
      'Response Due',
      'Your response is final once submitted.',
      'AppCapability.manageTanodTasks',
      'AppCapability.respondToTanodTasks',
      'TabangNowTheme.of(context)',
    ]) {
      expect(screen, contains(marker), reason: 'Missing $marker');
    }
  });
}
