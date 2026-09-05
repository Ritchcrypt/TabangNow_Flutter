import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Incident report initial status follows Laravel Reported workflow', () {
    final reportScreen = File(
      'lib/screens/report_incident_screen.dart',
    ).readAsStringSync();

    final incidentService = File(
      'lib/services/incident_service.dart',
    ).readAsStringSync();

    expect(
      reportScreen,
      contains("_submissionInfo['initial_status']?.toString() ?? 'Reported'"),
    );

    expect(
      reportScreen,
      isNot(
        contains("_submissionInfo['initial_status']?.toString() ?? 'Pending'"),
      ),
    );

    expect(incidentService, isNot(contains("..fields['status']")));

    expect(incidentService, isNot(contains("..fields['status_id']")));
  });
}
