import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tanod Roster is a live globally registered module', () {
    final registry = File('lib/core/module_registry.dart').readAsStringSync();

    final start = registry.indexOf('id: AppModuleId.tanodRoster,');

    expect(start, greaterThanOrEqualTo(0));

    final next = registry.indexOf('AppModuleDefinition(', start + 1);

    final block = registry.substring(start, next >= 0 ? next : registry.length);

    expect(block, contains("defaultLabel: 'Tanod Roster'"));

    expect(block, contains("websiteGlyph: '👥'"));

    expect(block, contains('mobileImplemented: true'));

    expect(registry, contains('AppCapability.viewTanodRoster'));
  });

  test(
    'HomeScreen routes Tanod Roster without losing global shell safeguards',
    () {
      final home = File('lib/screens/home_screen.dart').readAsStringSync();

      for (final required in <String>[
        "import 'tanod_roster_screen.dart';",
        '_HomeModule.tanodRoster',
        'AppModuleId.tanodRoster',
        'TanodRosterScreen(',
        'GlobalThemeButton(',
        'GlobalNotificationBell(',
        'ModuleRegistry.canAccess(',
        'scaffoldState.isDrawerOpen',
      ]) {
        expect(
          home,
          contains(required),
          reason: 'HomeScreen is missing $required',
        );
      }

      expect(home, isNot(contains("tooltip: 'Refresh'")));
    },
  );

  test('Tanod Roster mobile screen mirrors website fields and actions', () {
    final screen = File(
      'lib/screens/tanod_roster_screen.dart',
    ).readAsStringSync();

    for (final expected in <String>[
      'Tanod Roster',
      'on duty •',
      'Add Tanod',
      'Search Roster',
      'Assigned Barangay',
      'Shift',
      'responses',
      'Status',
      'Edit Tanod',
      'Date Appointed',
      'Contact Number',
      'Assigned Barangay *',
      'Notes',
      'accepted Tanod Task responses',
      'Tanod member deleted successfully.',
      'TabangNowTheme.of(context)',
    ]) {
      expect(
        screen,
        contains(expected),
        reason: 'Roster parity screen is missing $expected',
      );
    }
  });

  test('Tanod Roster client guard allows only Admin and Official aliases', () {
    final screen = File(
      'lib/screens/tanod_roster_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("_role == 'admin'"));

    expect(screen, contains("_role == 'official'"));

    expect(screen, contains("_role == 'dao'"));

    expect(screen, isNot(contains("_role == 'tanod' ||")));
  });
}
