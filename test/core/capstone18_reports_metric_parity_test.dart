import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Capstone 18 Reports exposes six website metrics and custom dates', () {
    final screen = File('lib/screens/reports_screen.dart').readAsStringSync();

    for (final metric in <String>[
      "key: 'total'",
      "key: 'active'",
      "key: 'critical'",
      "key: 'resolved'",
      "key: 'distress'",
      "key: 'tanod'",
    ]) {
      expect(screen, contains(metric));
    }

    expect(screen, contains("_period = 'week'"));
    expect(screen, contains("_period == 'custom'"));
    expect(screen, contains('DateTimeRange'));
    expect(screen, contains('showDateRangePicker'));
  });

  test('Capstone 18 Reports removes user-facing Case Management report actions', () {
    final screen = File('lib/screens/reports_screen.dart').readAsStringSync();

    expect(screen, isNot(contains('Case PDF')));
    expect(screen, isNot(contains('Case Report')));
    expect(screen, isNot(contains('Cases Filed')));
    expect(screen, contains('Record Preview'));
    expect(screen, contains('Select Records PDF'));
  });
}
