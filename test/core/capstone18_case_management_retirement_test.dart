import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Case Management active mobile implementation is fully retired', () {
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

    // Historical notification target remains compatible.
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

    for (final path in <String>[
      'lib/screens/case_form_screen.dart',
      'lib/screens/case_management_screen.dart',
      'lib/services/case_management_service.dart',
    ]) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path must remain retired.',
      );
    }
  });
}
