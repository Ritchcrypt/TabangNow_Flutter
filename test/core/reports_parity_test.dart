import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reports is live in ModuleRegistry and HomeScreen', () {
    final registry = File('lib/core/module_registry.dart').readAsStringSync();
    final reportsStart = registry.indexOf('id: AppModuleId.reports,');

    expect(reportsStart, greaterThanOrEqualTo(0));

    final next = registry.indexOf('AppModuleDefinition(', reportsStart + 1);
    final block = registry.substring(
      reportsStart,
      next >= 0 ? next : registry.length,
    );

    expect(block, contains('mobileImplemented: true'));

    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    for (final marker in <String>[
      "import 'reports_screen.dart';",
      '_HomeModule.reports',
      'AppModuleId.reports => _HomeModule.reports,',
      '_HomeModule.reports => AppModuleId.reports,',
      'return ReportsScreen(',
      'GlobalThemeButton(',
      'GlobalNotificationBell(',
      'ModuleRegistry.canAccess(',
      'scaffoldState.isDrawerOpen',
    ]) {
      expect(home, contains(marker));
    }
  });

  test('Reports screen matches Capstone 18 metric and timeline workflow', () {
    final screen = File('lib/screens/reports_screen.dart').readAsStringSync();

    for (final marker in <String>[
      "'Reports'",
      'Dao, Capiz —',
      'Today',
      'Last 7 Days',
      'Last 30 Days',
      'This Year',
      'Custom / Previous Dates',
      'showDateRangePicker',
      'Total Incidents',
      'Active Incidents',
      'Critical Incidents',
      'Resolved Incidents',
      'Distress Signals / SOS',
      'Tanod On Duty',
      'Records Breakdown',
      'Tap any record to preview it without leaving Reports.',
      'Record Preview',
      'Select Records PDF',
      'Download PDF',
      'Download All',
      'Selected (',
    ]) {
      expect(screen, contains(marker), reason: 'Missing report marker: $marker');
    }

    expect(screen, isNot(contains("'Case PDF'")));
    expect(screen, isNot(contains("'Cases Filed'")));
    expect(screen, isNot(contains("'Tanod Response Summary'")));
  });

  test('ReportService uses metric, custom range, and selected-record APIs', () {
    final service = File('lib/services/report_service.dart').readAsStringSync();

    for (final marker in <String>[
      '/api/v1/reports',
      '/api/v1/reports/pdf',
      '/api/v1/reports/selection/pdf',
      "'metric': metric",
      "'date_from': dateFrom",
      "'date_to': dateTo",
      "'selection_mode': selectionMode",
      "'records': recordKeys",
      'DownloadedReportPdf',
      'content-disposition',
      'response.bodyBytes',
    ]) {
      expect(service, contains(marker), reason: 'Missing ReportService marker: $marker');
    }
  });

  test('PDF workflow persists and opens the generated server PDF', () {
    final screen = File('lib/screens/reports_screen.dart').readAsStringSync();

    for (final marker in <String>[
      'getApplicationDocumentsDirectory',
      'TabangNow Reports',
      'writeAsBytes',
      'OpenFilex.open',
      'Print/Share menu',
    ]) {
      expect(screen, contains(marker));
    }
  });

  test('Reports remains Admin-only in Flutter capabilities', () {
    final capabilities = File('lib/core/app_capabilities.dart').readAsStringSync();

    expect(capabilities, contains('AppCapability.viewReports'));

    final officialStart = capabilities.indexOf('case AppRole.official:');
    final tanodStart = capabilities.indexOf('case AppRole.tanod:');
    final adminStart = capabilities.indexOf('case AppRole.admin:');

    expect(adminStart, greaterThanOrEqualTo(0));
    expect(officialStart, greaterThan(adminStart));

    final adminBlock = capabilities.substring(adminStart, officialStart);
    final officialBlock = capabilities.substring(officialStart, tanodStart);

    expect(adminBlock, contains('AppCapability.viewReports'));
    expect(officialBlock, isNot(contains('AppCapability.viewReports')));
  });
}
