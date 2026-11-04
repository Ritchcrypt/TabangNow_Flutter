import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Incident detail matches current website-visible features', () {
    final source = File(
      'lib/screens/incident_detail_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      "title: 'Incident Summary'",
      "label: 'Incident Type'",
      "label: 'Current Status'",
      "label: 'Severity'",
      "label: 'Date Reported'",
      "label: 'Time Reported'",
      "title: 'Description'",
      "title: 'Location Details'",
      "title: 'Evidence / Attachments'",
      "title: 'Reporter Information'",
      "title: 'Record Info'",
      "title: 'Update Incident'",
      "labelText: 'Status'",
      "child: const Text('Save Update')",
      "title: 'Escalate Incident'",
      "labelText: 'Agency'",
      "labelText: 'Escalation Reason'",
      "title: 'Status History'",
    ]) {
      expect(
        source,
        contains(marker),
        reason: 'Missing website marker: $marker',
      );
    }
  });

  test('removed Incident UI is not reintroduced', () {
    final source = File(
      'lib/screens/incident_detail_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      "incident['persons_involved']",
      "label: 'Incident Code'",
      '_remarksController',
      '_messageController',
      'Incident Messages',
      'Escalation History',
      'Danger Zone',
      '_sendMessage',
      '_deleteIncident',
    ]) {
      expect(
        source,
        isNot(contains(marker)),
        reason: 'Website does not expose: $marker',
      );
    }
  });

  test('status update supports authorized responder assignment', () {
    final source = File(
      'lib/screens/incident_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains('widget.incidentService.updateStatus('));
    expect(source, contains('statusId: statusId'));
    expect(
      source,
      contains("includeAssignedTo: _can('can_assign') && _assignmentChanged"),
    );
    expect(source, contains('assignedTo: _selectedResponderId'));
    expect(source, contains('_selectedResponderId'));
    expect(source, contains('_assignmentChanged'));
    expect(source, isNot(contains('remarks:')));
  });

  test('retired Case Management UI is absent from incident details', () {
    final detail = File(
      'lib/screens/incident_detail_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      "title: 'Related Cases'",
      '_RelatedCasesSection',
      '_RelatedCaseCard',
      'onCreateCase',
      'CaseManagementService',
      'CaseFormScreen',
      '_createRelatedCase',
    ]) {
      expect(detail, isNot(contains(marker)), reason: 'Retired UI: $marker');
    }

    for (final path in <String>[
      'lib/screens/case_form_screen.dart',
      'lib/screens/case_management_screen.dart',
      'lib/services/case_management_service.dart',
    ]) {
      expect(File(path).existsSync(), isFalse);
    }
  });
  test('Incident list keeps website controls and numeric ID display', () {
    final source = File('lib/screens/incidents_screen.dart').readAsStringSync();

    for (final marker in <String>[
      "labelText: 'Search'",
      "labelText: 'Status'",
      "labelText: 'Severity'",
      "label: const Text('Report Incident')",
      "label: const Text('View')",
    ]) {
      expect(source, contains(marker));
    }

    expect(source, isNot(contains("incident['incident_code']")));
  });
}
