import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Resident Complaints and Map are live in ModuleRegistry', () {
    final registry = File('lib/core/module_registry.dart').readAsStringSync();

    for (final moduleId in <String>['residentComplaints', 'barangayMap']) {
      final start = registry.indexOf('id: AppModuleId.$moduleId,');

      expect(start, greaterThanOrEqualTo(0));

      final next = registry.indexOf('AppModuleDefinition(', start + 1);

      final block = registry.substring(
        start,
        next >= 0 ? next : registry.length,
      );

      expect(block, contains('mobileImplemented: true'));
    }
  });

  test(
    'HomeScreen wires both modules and Resident Complaint notification deep-link',
    () {
      final home = File('lib/screens/home_screen.dart').readAsStringSync();

      for (final marker in <String>[
        "import 'resident_complaints_screen.dart';",
        "import 'resident_complaint_detail_screen.dart';",
        "import 'barangay_map_screen.dart';",
        "import '../services/resident_complaint_service.dart';",
        '_HomeModule.residentComplaints',
        '_HomeModule.barangayMap',
        'AppModuleId.residentComplaints',
        'AppModuleId.barangayMap',
        'ResidentComplaintsScreen(',
        'BarangayMapScreen(',
        "case 'residentComplaints':",
        'ResidentComplaintDetailScreen(',
        'target.sourceId',
        'GlobalThemeButton(',
        'GlobalNotificationBell(',
        'ModuleRegistry.canAccess(',
        'scaffoldState.isDrawerOpen',
      ]) {
        expect(
          home,
          contains(marker),
          reason: 'Missing HomeScreen marker: $marker',
        );
      }

      expect(
        home,
        isNot(
          contains(
            "_showPendingModule(\n"
            "          _appRole == AppRole.resident\n"
            "              ? 'Complaints Form'",
          ),
        ),
      );

      expect(home, isNot(contains("tooltip: 'Refresh'")));
    },
  );

  test('Resident Feedback includes secure website workflows', () {
    final service = File(
      'lib/services/resident_complaint_service.dart',
    ).readAsStringSync();

    final list = File(
      'lib/screens/resident_complaints_screen.dart',
    ).readAsStringSync();

    final create = File(
      'lib/screens/resident_complaint_create_screen.dart',
    ).readAsStringSync();

    final detail = File(
      'lib/screens/resident_complaint_detail_screen.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      '/api/v1/resident-complaints',
      '/status',
      '/proofs',
      '/evidence',
      '/api/v1/resident-complaint-proofs/',
      'MultipartRequest',
      'proof_picture',
    ]) {
      expect(service, contains(marker));
    }

    for (final marker in <String>[
      'My Feedback',
      'Resident Feedback',
      'Send Feedback',
      'View feedback',
      'Load More',
    ]) {
      expect(list, contains(marker));
    }

    for (final marker in <String>[
      'Resident Name *',
      'Contact Number',
      'What is this feedback about? *',
      'Feedback Type *',
      'Service / Experience Rating',
      'Location / Service Area',
      'Feedback Details *',
      'Supporting Picture',
      '10MB',
    ]) {
      expect(create, contains(marker));
    }

    for (final marker in <String>[
      'Feedback Information',
      'Resident Submitted Evidence',
      'Admin / Official Action Proof',
      'Send Action Proof Picture to Resident',
      'Update Status',
      'Save Status',
      'Delete Feedback',
    ]) {
      expect(detail, contains(marker));
    }
  });

  test(
    'Barangay Map includes pins, heatmap, legend and Incident deep-link',
    () {
      final service = File(
        'lib/services/barangay_map_service.dart',
      ).readAsStringSync();

      final screen = File(
        'lib/screens/barangay_map_screen.dart',
      ).readAsStringSync();

      expect(service, contains('/api/v1/barangay-map'));

      for (final marker in <String>[
        'Barangay Map',
        'Incident location pins and heatmap based on reported incidents.',
        'MAPPED INCIDENTS',
        'Incident Map View',
        'Pins',
        'Heatmap',
        'MAP LEGEND',
        'OpenStreetMap contributors',
        'View Incident',
        'IncidentDetailScreen(',
        'heat_intensity',
        'pin_color',
      ]) {
        expect(screen, contains(marker));
      }
    },
  );

  test('Development login bypass and global shell stay intact', () {
    final gate = File('lib/screens/dev_session_gate.dart');

    if (gate.existsSync()) {
      final text = gate.readAsStringSync();

      expect(text, isNot(contains('return const LoginScreen()')));

      expect(text, isNot(contains('Open Login')));
    }

    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(home, contains('GlobalThemeButton('));
    expect(home, contains('GlobalNotificationBell('));
  });
}
