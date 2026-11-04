import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity Logs includes the administrator recovery action', () {
    final screen = File('lib/screens/activity_logs_screen.dart').readAsStringSync();
    expect(screen, contains('Deleted Data Recovery'));
    expect(screen, contains('DeletedDataRecoveryScreen('));
    expect(screen, contains('if (_role == AppRole.admin)'));
  });

  test('mobile recovery screen confirms restore and shows filters', () {
    final screen = File('lib/screens/deleted_data_recovery_screen.dart').readAsStringSync();
    for (final marker in <String>[
      'Restore deleted data?',
      'Recoverable',
      'Restored',
      'Data type',
      'Apply filters',
      'Original ID',
    ]) {
      expect(screen, contains(marker));
    }
  });

  test('mobile recovery calls protected Laravel API', () {
    final service = File('lib/services/deleted_data_recovery_service.dart').readAsStringSync();
    expect(service, contains('/api/v1/deleted-data-recovery'));
    expect(service, contains('Authorization'));
    expect(service, contains(r'Bearer $token'));
    expect(service, contains('http.Client'));
  });
}
