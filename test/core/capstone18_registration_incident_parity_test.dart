import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resident registration sends the Capstone 18 age contract', () {
    final service = File(
      'lib/services/registration_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/screens/register_screen.dart',
    ).readAsStringSync();

    expect(service, contains("'date_of_birth': dateOfBirth.trim()"));
    expect(service, contains("'age_confirmation': ageConfirmation"));
    expect(screen, contains('Resident age requirement'));
    expect(screen, contains('_dateOfBirthController'));
    expect(screen, contains('_ageConfirmed'));
    expect(screen, contains('_latestEligibleBirthDate'));
  });

  test('resident and tanod incident reports cannot authoritatively set severity', () {
    final source = File(
      'lib/screens/report_incident_screen.dart',
    ).readAsStringSync();

    expect(source, contains('bool get _canAssessSeverity'));
    expect(source, contains("_role == 'admin' || _role == 'official' || _role == 'dao'"));
    expect(source, contains('Severity assessment'));
    expect(
      source,
      contains("priority: _canAssessSeverity ? (_priority ?? 'low') : 'low'"),
    );
  });
}
