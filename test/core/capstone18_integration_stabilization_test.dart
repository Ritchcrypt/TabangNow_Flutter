import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Capstone 18 integration stabilization', () {
    test('Case Management active implementation remains removed', () {
      final appModule = File('lib/core/app_module.dart').readAsStringSync();

      final capabilities = File(
        'lib/core/app_capabilities.dart',
      ).readAsStringSync();

      final registry = File('lib/core/module_registry.dart').readAsStringSync();

      final home = File('lib/screens/home_screen.dart').readAsStringSync();

      final incidentDetail = File(
        'lib/screens/incident_detail_screen.dart',
      ).readAsStringSync();

      expect(appModule.contains('caseManagement,'), isFalse);
      expect(capabilities.contains('viewCaseManagement'), isFalse);
      expect(capabilities.contains('manageCases'), isFalse);
      expect(registry.contains('AppModuleId.caseManagement'), isFalse);

      expect(home.contains("import 'case_management_screen.dart';"), isFalse);

      expect(home.contains('_HomeModule.caseManagement'), isFalse);
      expect(home.contains('CaseManagementScreen('), isFalse);
      expect(home.contains('AppModuleId.caseManagement'), isFalse);

      // Keep old notification records harmless and compatible.
      expect(home.contains("case 'caseManagement':"), isTrue);

      expect(
        RegExp(
          r"case\s+'caseManagement':"
          r'[\s\S]{0,450}'
          r'_selectModule\(_HomeModule\.dashboard\);',
        ).hasMatch(home),
        isTrue,
      );

      expect(incidentDetail.contains('CaseManagementService'), isFalse);
      expect(incidentDetail.contains('CaseFormScreen'), isFalse);
      expect(incidentDetail.contains('_createRelatedCase'), isFalse);
      expect(incidentDetail.contains('onCreateCase: null'), isTrue);
    });

    test('Reports parity metrics remain available', () {
      final reports = File(
        'lib/screens/reports_screen.dart',
      ).readAsStringSync();

      for (final label in <String>[
        'Total Incidents',
        'Active Incidents',
        'Critical Incidents',
        'Resolved Incidents',
        'Distress Signals / SOS',
        'Tanod On Duty',
      ]) {
        expect(
          reports.contains(label),
          isTrue,
          reason: 'Reports must retain $label.',
        );
      }
    });

    test('Firebase push startup and authenticated sync remain wired', () {
      final main = File('lib/main.dart').readAsStringSync();

      final home = File('lib/screens/home_screen.dart').readAsStringSync();

      expect(main.contains('NativePushService.instance.initialize()'), isTrue);

      expect(
        home.contains('NativePushService.instance.syncForAuthenticatedUser'),
        isTrue,
      );
    });

    test('established notification channels and sounds remain wired', () {
      final alert = File(
        'lib/services/background_notification_alert_service.dart',
      ).readAsStringSync();

      expect(alert.contains('tabangnow_notifications_v4'), isTrue);
      expect(alert.contains('tabangnow_notification_v4'), isTrue);
      expect(alert.contains('tabangnow_moderate_v1'), isTrue);
      expect(alert.contains('tabangnow_low_v1'), isTrue);
    });

    test('all established Android raw sound resources exist', () {
      for (final path in <String>[
        'android/app/src/main/res/raw/tabangnow_notification_v4.mp3',
        'android/app/src/main/res/raw/tabangnow_notification.wav',
        'android/app/src/main/res/raw/tabangnow_moderate_v1.mp3',
        'android/app/src/main/res/raw/tabangnow_low_v1.mp3',
      ]) {
        final file = File(path);

        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    test('Dart source contains no known mojibake markers', () {
      final lib = Directory('lib');

      for (final entity in lib.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final text = entity.readAsStringSync();

        expect(
          text.contains('Â'),
          isFalse,
          reason: 'Mojibake found in ${entity.path}',
        );

        expect(
          text.contains('â€'),
          isFalse,
          reason: 'Mojibake found in ${entity.path}',
        );
      }
    });
  });
}
