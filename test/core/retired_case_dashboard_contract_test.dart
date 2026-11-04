import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile dashboard uses incident metrics, not retired cases', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(home.contains("label: 'Active Incidents'"), isTrue);
    expect(home.contains("label: 'Active Cases'"), isFalse);
    expect(home.contains("value('active_cases')"), isFalse);
    expect(home.contains("value('resolved_cases')"), isFalse);
    expect(home.contains("value('active_incidents')"), isTrue);
    expect(home.contains("value('resolved_incidents')"), isTrue);
  });
}
