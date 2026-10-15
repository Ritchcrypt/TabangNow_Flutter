import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Capstone 18 announcement create sends barangay targeting', () {
    final service = File(
      'lib/services/announcement_service.dart',
    ).readAsStringSync();

    final create = File(
      'lib/screens/announcement_create_screen.dart',
    ).readAsStringSync();

    expect(service, contains("'barangay_ids': barangayIds"));
    expect(service, contains('/api/v1/incidents/options'));

    for (final marker in <String>[
      'Target Barangays *',
      'Select at least one target barangay.',
      'Select All',
      'Only users assigned to the selected barangays',
      'barangayIds: _selectedBarangayIds.toList()..sort()',
    ]) {
      expect(create, contains(marker));
    }
  });

  test('announcement list provides canonical barangays to create flow', () {
    final screen = File(
      'lib/screens/announcements_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('await _service.barangayOptions()'));
    expect(screen, contains('barangays: barangays'));
    expect(
      screen,
      contains(
        'No official Dao barangays are available for announcement targeting.',
      ),
    );
  });
}
