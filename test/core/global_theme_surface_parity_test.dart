import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const targets = <String>[
    'lib/screens/home_screen.dart',
    'lib/screens/incidents_screen.dart',
    'lib/screens/report_incident_screen.dart',
    'lib/screens/incident_detail_screen.dart',
    'lib/screens/tanod_alerts_screen.dart',
    'lib/screens/system_branding_screen.dart',
  ];

  const prohibitedNeutralLiterals = <String>[
    'Color(0xFFF8FAFC)',
    'Color(0xFFF8FBFF)',
    'Color(0xFFF1F5F9)',
    'Color(0xFFE2E8F0)',
    'Color(0xFFCBD5E1)',
    'Color(0xFF0F172A)',
    'Color(0xFF334155)',
    'Color(0xFF475569)',
    'Color(0xFF64748B)',
    'Color(0xFF94A3B8)',
  ];

  test(
    'implemented authenticated screens use centralized neutral theme tokens',
    () {
      for (final path in targets) {
        final file = File(path);

        if (!file.existsSync()) {
          continue;
        }

        final source = file.readAsStringSync();

        expect(
          source,
          contains("import '../core/tabangnow_theme.dart';"),
          reason: '$path must import TabangNowTheme.',
        );

        for (final literal in prohibitedNeutralLiterals) {
          expect(
            source,
            isNot(contains(literal)),
            reason: '$path still hard-codes website neutral token $literal.',
          );
        }

        expect(
          source,
          isNot(contains('backgroundColor: Colors.white')),
          reason: '$path still pins a Material background to light mode.',
        );

        expect(
          source,
          isNot(contains('surfaceTintColor: Colors.white')),
          reason: '$path still pins a Material surface tint to light mode.',
        );

        expect(
          source,
          isNot(contains('fillColor: Colors.white')),
          reason: '$path still pins an input surface to light mode.',
        );
      }
    },
  );

  test('website-equivalent global palette exists', () {
    final source = <String>[
      File('lib/core/global_theme_controller.dart').readAsStringSync(),
      File('lib/core/tabangnow_theme.dart').readAsStringSync(),
    ].join('\n');

    for (final value in <String>[
      '0xFF020617',
      '0xFF0F172A',
      '0xFF111827',
      '0xFF1E293B',
      '0xFF334155',
      '0xFF475569',
      '0xFFF8FAFC',
      '0xFFE2E8F0',
      '0xFFCBD5E1',
      '0xFF64748B',
      '0xFF2563EB',
    ]) {
      expect(
        source,
        contains(value),
        reason: 'Central palette is missing website token $value.',
      );
    }
  });
}
