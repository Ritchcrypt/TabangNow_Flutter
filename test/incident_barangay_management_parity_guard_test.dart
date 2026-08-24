import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incident Add Barangay mirrors website inline quick-add behavior', () {
    final source = File(
      'lib/screens/report_incident_screen.dart',
    ).readAsStringSync();

    expect(source, contains("_permissions['can_manage_barangays'] == true"));
    expect(source, contains('void _toggleAddBarangayPanel()'));
    expect(source, contains('Future<void> _saveBarangay() async'));
    expect(
      source,
      contains('if (_canManageBarangays && _showAddBarangayPanel)'),
    );
    expect(source, contains("'Enter a barangay name first.'"));
    expect(source, contains("'Save Barangay'"));
    expect(source, contains('createdIsAvailable'));
    expect(source, contains('key: ValueKey<int?>(_barangayId)'));
    expect(source, isNot(contains('Future<void> _addBarangay() async')));
  });

  test('incident service keeps the Laravel barangay quick-store contract', () {
    final service = File(
      'lib/services/incident_service.dart',
    ).readAsStringSync();

    expect(service, contains('/api/v1/incidents/barangays'));
    expect(service, contains("'barangay_name': name.trim()"));
  });
}
