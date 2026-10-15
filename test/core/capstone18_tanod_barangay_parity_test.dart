import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tanod Roster uses canonical barangay assignment contract', () {
    final service = File(
      'lib/services/tanod_roster_service.dart',
    ).readAsStringSync();

    final screen = File(
      'lib/screens/tanod_roster_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      "'barangay_id': barangayId",
      'required int barangayId',
    ]) {
      expect(service, contains(marker));
    }

    for (final marker in <String>[
      'Assigned Barangay',
      'Assigned Barangay *',
      "options['barangays']",
      "tanod['barangay_name']",
      'Incident response tasks for this barangay are offered to its tanods first.',
    ]) {
      expect(screen, contains(marker));
    }

    expect(
      screen,
      isNot(contains("labelText: 'Purok Assignment'")),
      reason: 'Purok must no longer be the user-facing assignment field.',
    );
  });

  test('Tanod Task creation is barangay-first with fallback messaging', () {
    final service = File(
      'lib/services/tanod_task_service.dart',
    ).readAsStringSync();

    final screen = File(
      'lib/screens/tanod_tasks_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      "'barangay_id': barangayId",
      'required int barangayId',
    ]) {
      expect(service, contains(marker));
    }

    for (final marker in <String>[
      'Response Barangay *',
      "options['barangays']",
      "task['barangay_name']",
      "task['fallback_used']",
      'selected barangay receive this task first',
      'active tanods from other Dao barangays are used as fallback',
      'Routing starts with the selected barangay before fallback.',
    ]) {
      expect(screen, contains(marker));
    }

    expect(
      screen,
      isNot(
        contains(
          'This task will be assigned to all active tanods. Each tanod can accept or decline it.',
        ),
      ),
    );
  });
}
