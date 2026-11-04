import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved user theme is applied before HomeScreen is exposed', () {
    final source = File('lib/screens/auth_gate.dart').readAsStringSync();

    expect(source.contains("../core/global_theme_controller.dart"), isTrue);

    expect(source.contains('void _applyUserTheme('), isTrue);

    final applyCount = RegExp(
      r'_applyUserTheme\(user\);',
    ).allMatches(source).length;

    expect(applyCount, greaterThanOrEqualTo(2));

    expect(source.contains("user['theme_mode']"), isTrue);

    expect(source.contains("user['theme_custom_color']"), isTrue);
  });
}
